import cv2
import json
import argparse
from pathlib import Path
import numpy as np
import mediapipe as mp
from bvh_exporter import build_skeleton_from_first_frame, compute_bvh_frames, write_bvh_file

## This script was used to generate animated-skeletons of signs from human-signer videos
# Original videos of the human signer are not included for privacy

mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles
mp_holistic = mp.solutions.holistic
mp_face_mesh = mp.solutions.face_mesh
mp_hands = mp.solutions.hands

POSE_CONNECTIONS = mp_holistic.POSE_CONNECTIONS
HAND_CONNECTIONS = mp_hands.HAND_CONNECTIONS

# FaceMesh contour loops
MOUTH_OUTER = [61, 146, 91, 181, 84, 314, 405, 321, 375, 291]
MOUTH_INNER = [78, 95, 88, 178, 87, 317, 402, 318, 324, 308]
UPPER_LIP_LOOP = [61, 40, 37, 267, 270, 409, 291]

LEFT_EYE_LOOP  = [33, 246, 161, 160, 159, 158, 157, 173,
                  133, 155, 154, 153, 145, 144, 163, 7]
RIGHT_EYE_LOOP = [362, 398, 384, 385, 386, 387, 388, 466,
                  263, 249, 390, 373, 374, 380, 381, 382]

LEFT_BROW_LOOP  = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
RIGHT_BROW_LOOP = [336, 296, 334, 293, 300, 276, 283, 282, 295, 285]


def smooth_landmarks(prev_landmarks, cur_landmarks, alpha: float = 0.8):
    """Exponential smoothing over time: new = alpha * prev + (1 - alpha) * cur.
    prev_landmarks / cur_landmarks are dicts with keys pose/left_hand/right_hand/face.
    Each value is a list of (x, y, z) or None."""
    if prev_landmarks is None:
        return cur_landmarks

    out = {}
    for k, cur in cur_landmarks.items():
        prev = prev_landmarks.get(k)
        if cur is None:
            out[k] = None
            continue
        if prev is None:
            out[k] = cur
            continue

        new_list = []
        for pcur, pprev in zip(cur, prev):
            x = alpha * pprev[0] + (1.0 - alpha) * pcur[0]
            y = alpha * pprev[1] + (1.0 - alpha) * pcur[1]
            z = alpha * pprev[2] + (1.0 - alpha) * pcur[2]
            new_list.append((x, y, z))
        out[k] = new_list

    return out


def center_and_scale_landmarks(landmarks, reference_pairs=[(11, 12)]):
    """
    Center everything around mid-hips (23,24) if available, else shoulders (11,12),
    and scale so the mean distance of reference_pairs is ~1.
    """
    pose = landmarks.get('pose')
    if pose is None:
        return landmarks

    def midpoint(a, b):
        return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)

    try:
        center = midpoint(pose[23], pose[24])
    except Exception:
        center = midpoint(pose[11], pose[12])

    scales = []
    for a, b in reference_pairs:
        try:
            pa, pb = pose[a], pose[b]
            scales.append(np.hypot(pa[0] - pb[0], pa[1] - pb[1]))
        except Exception:
            continue

    s = float(np.mean(scales)) if scales else 1.0
    if s == 0:
        s = 1.0

    out = {}
    for k, lst in landmarks.items():
        if lst is None:
            out[k] = None
            continue
        normed = [((p[0] - center[0]) / s,
                   (p[1] - center[1]) / s,
                   p[2] / s)
                  for p in lst]
        out[k] = normed

    return out


def draw_skeleton_on_transparent(img_w, img_h, landmarks_pixel,
                                 draw_face: bool = False,
                                 draw_inner_mouth: bool = True):
    # Draw pose + hands (+ optional face) as a white skeleton onto an RGBA canvas. Arms come from the pose model, hands from MediaPipe Hands.
    canvas = np.zeros((img_h, img_w, 4), dtype=np.uint8)

    def draw_point(pt, radius=4):
        if pt is None:
            return
        cv2.circle(canvas, (int(pt[0]), int(pt[1])), radius,
                   (255, 255, 255, 255), -1)

    def draw_line(a, b, thickness=2):
        if a is None or b is None:
            return
        cv2.line(canvas,
                 (int(a[0]), int(a[1])),
                 (int(b[0]), int(b[1])),
                 (255, 255, 255, 255),
                 thickness)

    def draw_closed_loop(points, thickness=2):
        n = len(points)
        if n < 2:
            return
        for i in range(n):
            a = points[i]
            b = points[(i + 1) % n]
            if a is None or b is None:
                continue
            cv2.line(canvas, (int(a[0]), int(a[1])),
                     (int(b[0]), int(b[1])),
                     (255, 255, 255, 255),
                     thickness)

    def draw_open_polyline(points, thickness=2):
        if len(points) < 2:
            return
        for i in range(len(points) - 1):
            a = points[i]
            b = points[i + 1]
            if a is None or b is None:
                continue
            cv2.line(canvas, (int(a[0]), int(a[1])),
                     (int(b[0]), int(b[1])),
                     (255, 255, 255, 255),
                     thickness)

    # Pose (body & arms; no fake fingers; no pose-face) 
    # Exclude connections that go beyond wrists into fake pose-fingers
    EXCLUDED_POSE_CONNECTIONS = {
        (15, 17), (17, 19), (19, 21),
        (16, 18), (18, 20), (20, 22),
    }

    # Pose indices that belong to the head – FaceMesh handles face
    POSE_FACE_IDXS = set(range(0, 11))

    # Pose hand-only joints (beyond wrists) – don't draw them as points
    POSE_HAND_ONLY_IDXS = {17, 18, 19, 20, 21, 22}

    pose = landmarks_pixel.get('pose')
    if pose is not None:
        for (start, end) in POSE_CONNECTIONS:
            if (start, end) in EXCLUDED_POSE_CONNECTIONS or (end, start) in EXCLUDED_POSE_CONNECTIONS:
                continue
            # skip pose connections that involve face
            if start in POSE_FACE_IDXS or end in POSE_FACE_IDXS:
                continue
            if start < len(pose) and end < len(pose):
                draw_line(pose[start], pose[end], thickness=3)

        for idx, p in enumerate(pose):
            if idx in POSE_FACE_IDXS or idx in POSE_HAND_ONLY_IDXS:
                continue
            draw_point(p, radius=3)

    # Hands (detailed, from mp_hands) 
    for hand_key in ('left_hand', 'right_hand'):
        hand = landmarks_pixel.get(hand_key)
        if hand is None:
            continue
        for s_idx, e_idx in HAND_CONNECTIONS:
            if s_idx < len(hand) and e_idx < len(hand):
                draw_line(hand[s_idx], hand[e_idx], thickness=3)
        for p in hand:
            draw_point(p, radius=4)

    # Face (from FaceMesh) 
    if draw_face:
        face = landmarks_pixel.get('face')
        if face is not None and len(face) > 0:
            mouth_outer = [face[i] if i < len(face) else None for i in MOUTH_OUTER]
            draw_closed_loop(mouth_outer, thickness=2)

            if draw_inner_mouth:
                mouth_inner = [face[i] if i < len(face) else None for i in MOUTH_INNER]
                draw_closed_loop(mouth_inner, thickness=2)

            upper_lip = [face[i] if i < len(face) else None for i in UPPER_LIP_LOOP]
            draw_open_polyline(upper_lip, thickness=2)

            left_eye = [face[i] if i < len(face) else None for i in LEFT_EYE_LOOP]
            right_eye = [face[i] if i < len(face) else None for i in RIGHT_EYE_LOOP]
            draw_closed_loop(left_eye, thickness=2)
            draw_closed_loop(right_eye, thickness=2)

            left_brow = [face[i] if i < len(face) else None for i in LEFT_BROW_LOOP]
            right_brow = [face[i] if i < len(face) else None for i in RIGHT_BROW_LOOP]
            draw_open_polyline(left_brow, thickness=2)
            draw_open_polyline(right_brow, thickness=2)

    return canvas


def extract_landmarks_from_results(results, w, h):
    # Extract pose + face landmarks from Holistic results (in pixel coords)
    # Hands will be overridden by the dedicated Hands model
    out = {}
    # Pose
    if results.pose_landmarks:
        out['pose'] = [(lm.x * w, lm.y * h, lm.z)
                       for lm in results.pose_landmarks.landmark]
    else:
        out['pose'] = None

    # Placeholder for hands (override later)
    out['left_hand'] = None
    out['right_hand'] = None

    # Face
    if results.face_landmarks:
        out['face'] = [(lm.x * w, lm.y * h, lm.z)
                       for lm in results.face_landmarks.landmark]
    else:
        out['face'] = None

    return out


def extract_hands_from_results(hands_results, w, h):
    left_hand = None
    right_hand = None

    if hands_results and hands_results.multi_hand_landmarks and hands_results.multi_handedness:
        for lm_list, handedness in zip(hands_results.multi_hand_landmarks,
                                       hands_results.multi_handedness):
            label = handedness.classification[0].label  # 'Left' or 'Right'
            coords = [(lm.x * w, lm.y * h, lm.z) for lm in lm_list.landmark]
            if label == 'Left':
                left_hand = coords
            elif label == 'Right':
                right_hand = coords

    return left_hand, right_hand

def process_video_file(path, output_dir, draw_skeleton, save_json, smooth, center_scale, draw_face, args):

    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        print(f"Failed to open {path}")
        return

    fps = cap.get(cv2.CAP_PROP_FPS) or 25
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    video_name = Path(path).stem
    frames_out_dir = Path(output_dir) / video_name / 'frames'
    frames_out_dir.mkdir(parents=True, exist_ok=True)
    json_out_path = Path(output_dir) / video_name / f"{video_name}_landmarks.json"

    frame_idx = 0
    prev_landmarks = None
    prev_hands = {'left': None, 'right': None}
    no_hands_run = 0  # how many consecutive frames with no detected hands
    MAX_NO_HAND_GAP = 2  # reuse last hands for at most 2 frames

    landmarks_all_frames = []
    bvh_frames = []

    with mp_holistic.Holistic(
        static_image_mode=False,
        model_complexity=2,
        smooth_landmarks=True,
        enable_segmentation=False,
        refine_face_landmarks=True,
        min_detection_confidence=0.2,
        min_tracking_confidence=0.2,
    ) as holistic, mp_hands.Hands(
        model_complexity=1,
        max_num_hands=2,
        min_detection_confidence=0.2,
        min_tracking_confidence=0.2,
    ) as hands:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # Holistic for pose + face
            results = holistic.process(rgb)

            # Dedicated hand model (more robust for fingers)
            hands_results = hands.process(rgb)

            # Pose + face
            raw_landmarks = extract_landmarks_from_results(results, w, h)

            # Hands from mp_hands
            left_hand, right_hand = extract_hands_from_results(hands_results, w, h)

            # If both hands detected and extremely close, treat as a single hand
            if left_hand is not None and right_hand is not None:
                lx, ly, _ = left_hand[0]
                rx, ry, _ = right_hand[0]
                min_dist = 0.05 * min(w, h)  # 5% of smallest dimension
                if (lx - rx) ** 2 + (ly - ry) ** 2 < min_dist ** 2:
                    # keep just one (right_hand by convention)
                    left_hand = None

            # Decide whether to reuse previous hands or let them disappear
            if left_hand is None and right_hand is None:
                no_hands_run += 1
                if no_hands_run <= MAX_NO_HAND_GAP and (prev_hands['left'] is not None or prev_hands['right'] is not None):
                    # short gap → keep last hands to avoid a blink
                    left_hand = prev_hands['left']
                    right_hand = prev_hands['right']
                else:
                    # long gap (e.g. end of video) → clear and let hands disappear
                    prev_hands = {'left': None, 'right': None}
            else:
                # we have at least one hand this frame = reset counter
                no_hands_run = 0

            raw_landmarks['left_hand'] = left_hand
            raw_landmarks['right_hand'] = right_hand

            # Temporal smoothing (pose + hands + face)
            if smooth:
                smoothed = smooth_landmarks(prev_landmarks, raw_landmarks, alpha=0.85)
            else:
                smoothed = raw_landmarks

            prev_landmarks = smoothed
            prev_hands['left'] = smoothed.get('left_hand')
            prev_hands['right'] = smoothed.get('right_hand')

            normalized = center_and_scale_landmarks(smoothed) if center_scale else None
            frame_record = {
                'frame_index': frame_idx,
                'raw': {},
                'smoothed': {},
                'normalized_centered': {},
            }
            for key, value in raw_landmarks.items():
                if value is None:
                    frame_record['raw'][key] = None
                else:
                    frame_record['raw'][key] = [
                        {'x': float(p[0]), 'y': float(p[1]), 'z': float(p[2])}
                        for p in value
                    ]
            for key, value in smoothed.items():
                if value is None:
                    frame_record['smoothed'][key] = None
                else:
                    frame_record['smoothed'][key] = [
                        {'x': float(p[0]), 'y': float(p[1]), 'z': float(p[2])}
                        for p in value
                    ]
            if normalized is not None:
                for key, value in normalized.items():
                    if value is None:
                        frame_record['normalized_centered'][key] = None
                    else:
                        frame_record['normalized_centered'][key] = [
                            {'x': float(p[0]), 'y': float(p[1]), 'z': float(p[2])}
                            for p in value
                        ]

            landmarks_all_frames.append(frame_record)
            # Collect positions for BVH
            if args.export_bvh:
                # For BVH we use normalized_centered = stable rotations
                norm = frame_record['normalized_centered']

                bvh_frame = {}

                # Pose (33 points) — essential for skeleton
                if norm['pose'] is not None:
                    bvh_frame['pose'] = [np.array([p['x'], p['y'], p['z']]) for p in norm['pose']]

                    # Compute hip center for root translation
                    lh = bvh_frame['pose'][23]
                    rh = bvh_frame['pose'][24]
                    bvh_frame['hips_center'] = (lh + rh) / 2.0

                # Hands (21×2 points)
                if norm['left_hand'] is not None:
                    bvh_frame['left_hand'] = [np.array([p['x'], p['y'], p['z']]) for p in norm['left_hand']]
                else:
                    bvh_frame['left_hand'] = None

                if norm['right_hand'] is not None:
                    bvh_frame['right_hand'] = [np.array([p['x'], p['y'], p['z']]) for p in norm['right_hand']]
                else:
                    bvh_frame['right_hand'] = None

                # Face (468 points)
                if norm['face'] is not None:
                    bvh_frame['face'] = [np.array([p['x'], p['y'], p['z']]) for p in norm['face']]
                else:
                    bvh_frame['face'] = None

                bvh_frames.append(bvh_frame)


            # Draw skeleton on transparent frame
            if draw_skeleton:
                canvas = draw_skeleton_on_transparent(w, h, smoothed, draw_face=draw_face)
                out_path = frames_out_dir / f"frame_{frame_idx:06d}.png"
                success = cv2.imwrite(str(out_path), canvas)
                print(f"Saving frame {frame_idx} -> {out_path}, success={success}, nonzero={np.sum(canvas) > 0}")

            frame_idx += 1

    cap.release()

    if save_json:
        json_obj = {
            'video': video_name,
            'fps': fps,
            'width': w,
            'height': h,
            'frames': landmarks_all_frames,
        }
        with open(json_out_path, 'w', encoding='utf-8') as f:
            json.dump(json_obj, f, ensure_ascii=False)
 
    if save_json and args.export_bvh:
        if len(bvh_frames) > 1:
            skeleton = build_skeleton_from_first_frame(bvh_frames[0])

            motion = compute_bvh_frames(skeleton, bvh_frames)

            bvh_out_path = Path(output_dir) / video_name / f"{video_name}.bvh"

            write_bvh_file(bvh_out_path, skeleton, motion, fps=fps)
        else:
            print("BVH export skipped (not enough frames).")

    print(f"Processed {path}: {frame_idx} frames. JSON -> {json_out_path}. Frames -> {frames_out_dir}")


def main():
    parser = argparse.ArgumentParser(
        description="Extract MediaPipe Holistic landmarks + draw skeleton frames."
    )
    parser.add_argument('--input_dir', required=True,
                        help='Directory containing input videos.')
    parser.add_argument('--output_dir', required=True,
                        help='Directory to store outputs (JSON + frames).')
    parser.add_argument('--draw_skeleton', action='store_true',
                        help='If set, draw skeleton frames as transparent PNGs.')
    parser.add_argument('--save_json', action='store_true',
                        help='If set, save landmarks JSON.')
    parser.add_argument('--smooth', action='store_true',
                        help='If set, apply temporal smoothing.')
    parser.add_argument('--draw_face', action='store_true',
                        help='If set, draw FaceMesh-based facial features.')

    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    video_files = [p for p in input_dir.iterdir()
                   if p.suffix.lower() in ('.mp4', '.mov', '.avi', '.mkv')]
    if not video_files:
        print('No video files found in input_dir')
        return

    for vf in video_files:
        process_video_file(
            vf,
            output_dir,
            draw_skeleton=args.draw_skeleton,
            save_json=args.save_json,
            smooth=args.smooth,
            center_scale=True,
            draw_face=args.draw_face,
            args=args
        )

    print("\nDone. To assemble transparent frames into a webm with alpha:")
    print("ffmpeg -framerate <FPS> -i frame_%06d.png -c:v libvpx-vp9 -pix_fmt yuva420p out_with_alpha.webm")
    print("Replace <FPS> with the original video's frames-per-second (check the JSON output).")


if __name__ == '__main__':
    main()
