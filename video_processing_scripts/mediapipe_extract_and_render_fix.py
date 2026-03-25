"""
mediapipe_extract_and_render.py
--------------------------------
Extracts pose + hands + face landmarks using MediaPipe Holistic ONLY.
Using a single model ensures hands are always correctly attached to the wrists.
"""

import cv2
import json
import argparse
from pathlib import Path
import numpy as np
import mediapipe as mp

mp_holistic  = mp.solutions.holistic
mp_hands_mod = mp.solutions.hands
mp_face_mesh = mp.solutions.face_mesh

POSE_CONNECTIONS = mp_holistic.POSE_CONNECTIONS
HAND_CONNECTIONS = mp_hands_mod.HAND_CONNECTIONS

# ── FaceMesh contour index lists ────────────────────────────────────────────
MOUTH_OUTER     = [61, 146, 91, 181, 84, 314, 405, 321, 375, 291]
MOUTH_INNER     = [78, 95, 88, 178, 87, 317, 402, 318, 324, 308]
UPPER_LIP_LOOP  = [61, 40, 37, 267, 270, 409, 291]
LEFT_EYE_LOOP   = [33, 246, 161, 160, 159, 158, 157, 173,
                   133, 155, 154, 153, 145, 144, 163, 7]
RIGHT_EYE_LOOP  = [362, 398, 384, 385, 386, 387, 388, 466,
                   263, 249, 390, 373, 374, 380, 381, 382]
LEFT_BROW_LOOP  = [70, 63, 105, 66, 107, 55, 65, 52, 53, 46]
RIGHT_BROW_LOOP = [336, 296, 334, 293, 300, 276, 283, 282, 295, 285]

# Pose landmark indices
POSE_FACE_IDXS      = set(range(0, 11))   # nose, eyes, ears, mouth
POSE_HAND_ONLY_IDXS = {17, 18, 19, 20, 21, 22}  # beyond wrists (fake fingers)

# Pose connections to exclude (fake fingers beyond wrists)
EXCLUDED_POSE_CONNECTIONS = {
    (15, 17), (17, 19), (19, 21),
    (16, 18), (18, 20), (20, 22),
}


# ── Helpers ──────────────────────────────────────────────────────────────────

def lm_to_pixels(landmark_list, w, h):
    """Convert a MediaPipe NormalizedLandmarkList to pixel (x, y, z) tuples."""
    return [(lm.x * w, lm.y * h, lm.z) for lm in landmark_list.landmark]


def smooth_landmarks(prev, cur, alpha: float = 0.5):
    """
    Exponential moving average per landmark key.
    alpha=0  pure current frame  (no smoothing)
    alpha=1  pure previous frame (freeze)
    On first appearance (prev key is None) we use the raw current value
    so the hand snaps to its real position instead of blending from nothing.
    """
    if prev is None:
        return cur

    out = {}
    for k, c in cur.items():
        p = prev.get(k)
        if c is None:
            out[k] = None
        elif p is None:
            out[k] = c          # first time this key appears: no blend
        else:
            out[k] = [
                (alpha * pp[0] + (1 - alpha) * cc[0],
                 alpha * pp[1] + (1 - alpha) * cc[1],
                 alpha * pp[2] + (1 - alpha) * cc[2])
                for pp, cc in zip(p, c)
            ]
    return out


def fill_hand_gap(cur_hand, prev_hand, no_hand_frames, max_gap,
                  pose_wrist=None, w=1, h=1):
    """
    Reuse the previous hand position for up to max_gap frames when the
    detector loses the hand briefly.

    Extra guard: if the pose wrist has moved more than 10% of the frame
    width away from where the held hand is, the signer has lowered their
    hand intentionally — clear immediately instead of holding.
    """
    if cur_hand is not None:
        return cur_hand, 0

    if prev_hand is not None and no_hand_frames < max_gap:
        # If pose wrist is available, check whether the arm has moved away
        if pose_wrist is not None:
            held_wrist_x, held_wrist_y = prev_hand[0][0], prev_hand[0][1]
            dist = np.hypot(pose_wrist[0] - held_wrist_x,
                            pose_wrist[1] - held_wrist_y)
            threshold = 0.10 * w   # 10 % of frame width
            if dist > threshold:
                # Wrist has moved far away — hand is genuinely gone
                return None, no_hand_frames + 1

        return prev_hand, no_hand_frames + 1

    return None, no_hand_frames + 1


def center_and_scale(landmarks, reference_pairs=((11, 12),)):
    """
    Translate so mid-hips (or mid-shoulders) is the origin, then scale so
    the shoulder width is approximately 1.  Used only for the JSON copy.
    """
    pose = landmarks.get('pose')
    if pose is None:
        return landmarks

    try:
        cx = (pose[23][0] + pose[24][0]) / 2.0
        cy = (pose[23][1] + pose[24][1]) / 2.0
    except Exception:
        cx = (pose[11][0] + pose[12][0]) / 2.0
        cy = (pose[11][1] + pose[12][1]) / 2.0

    scales = []
    for a, b in reference_pairs:
        try:
            scales.append(np.hypot(pose[a][0] - pose[b][0],
                                   pose[a][1] - pose[b][1]))
        except Exception:
            pass
    s = float(np.mean(scales)) if scales else 1.0
    if s == 0:
        s = 1.0

    out = {}
    for k, lst in landmarks.items():
        if lst is None:
            out[k] = None
        else:
            out[k] = [((p[0] - cx) / s,
                       (p[1] - cy) / s,
                       p[2]        / s) for p in lst]
    return out


# ── Drawing ──────────────────────────────────────────────────────────────────

def draw_skeleton(img_w, img_h, lm, draw_face=True, draw_inner_mouth=True):
    """
    Render pose + hands + (optionally) face onto a transparent RGBA canvas.
    All landmark data comes from a single Holistic pass so hands are
    guaranteed to be attached to the correct wrist positions.
    """
    canvas = np.zeros((img_h, img_w, 4), dtype=np.uint8)
    WHITE  = (255, 255, 255, 255)

    def pt(p):
        return (int(p[0]), int(p[1]))

    def dot(p, r=4):
        if p is not None:
            cv2.circle(canvas, pt(p), r, WHITE, -1)

    def line(a, b, t=2):
        if a is not None and b is not None:
            cv2.line(canvas, pt(a), pt(b), WHITE, t)

    def closed_loop(pts, t=2):
        n = len(pts)
        for i in range(n):
            line(pts[i], pts[(i + 1) % n], t)

    def open_poly(pts, t=2):
        for i in range(len(pts) - 1):
            line(pts[i], pts[i + 1], t)

    # ── Pose (body + arms, stop at wrists, skip face joints) ────────────────
    pose = lm.get('pose')
    if pose:
        for s, e in POSE_CONNECTIONS:
            if (s, e) in EXCLUDED_POSE_CONNECTIONS or (e, s) in EXCLUDED_POSE_CONNECTIONS:
                continue
            if s in POSE_FACE_IDXS or e in POSE_FACE_IDXS:
                continue
            if s < len(pose) and e < len(pose):
                line(pose[s], pose[e], 3)
        for i, p in enumerate(pose):
            if i in POSE_FACE_IDXS or i in POSE_HAND_ONLY_IDXS:
                continue
            dot(p, 3)

    # ── Hands (from Holistic, already aligned with pose wrists) ─────────────
    for hk in ('left_hand', 'right_hand'):
        hand = lm.get(hk)
        if not hand:
            continue
        for s, e in HAND_CONNECTIONS:
            if s < len(hand) and e < len(hand):
                line(hand[s], hand[e], 3)
        for p in hand:
            dot(p, 4)

    # ── Face (FaceMesh contours) ─────────────────────────────────────────────
    if draw_face:
        face = lm.get('face')
        if face:
            def fi(idx):
                return face[idx] if idx < len(face) else None

            closed_loop([fi(i) for i in MOUTH_OUTER], 2)
            if draw_inner_mouth:
                closed_loop([fi(i) for i in MOUTH_INNER], 2)
            open_poly([fi(i) for i in UPPER_LIP_LOOP], 2)
            closed_loop([fi(i) for i in LEFT_EYE_LOOP],  2)
            closed_loop([fi(i) for i in RIGHT_EYE_LOOP], 2)
            open_poly([fi(i) for i in LEFT_BROW_LOOP],  2)
            open_poly([fi(i) for i in RIGHT_BROW_LOOP], 2)

    return canvas


# ── Main processing ───────────────────────────────────────────────────────────

def process_video(path, output_dir,
                  draw_skeleton_frames=True,
                  save_json=True,
                  smooth=True,
                  draw_face=True):

    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        print(f"[ERROR] Cannot open {path}")
        return

    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    w   = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h   = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    name       = Path(path).stem
    frames_dir = Path(output_dir) / name / 'frames'
    json_path  = Path(output_dir) / name / f"{name}_landmarks.json"
    frames_dir.mkdir(parents=True, exist_ok=True)

    no_left  = 0
    no_right = 0
    MAX_GAP  = 2   # frames to bridge genuine detection blips only

    prev_lm    = None
    prev_left  = None
    prev_right = None
    all_frames = []
    frame_idx  = 0

    with mp_holistic.Holistic(
        static_image_mode        = False,
        model_complexity         = 2,
        smooth_landmarks         = True,
        enable_segmentation      = False,
        refine_face_landmarks    = True,
        min_detection_confidence = 0.3,
        min_tracking_confidence  = 0.3,
    ) as holistic:

        while True:
            ok, frame = cap.read()
            if not ok:
                break

            rgb     = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = holistic.process(rgb)

            # ── Extract raw landmarks ────────────────────────────────────────
            raw = {}

            raw['pose'] = (lm_to_pixels(results.pose_landmarks, w, h)
                           if results.pose_landmarks else None)

            raw['face'] = (lm_to_pixels(results.face_landmarks, w, h)
                           if results.face_landmarks else None)

            # Holistic hand landmarks share the same coordinate space as pose,
            # so hand landmark 0 (wrist) is exactly at the pose wrist position.
            raw_left  = (lm_to_pixels(results.left_hand_landmarks,  w, h)
                         if results.left_hand_landmarks  else None)
            raw_right = (lm_to_pixels(results.right_hand_landmarks, w, h)
                         if results.right_hand_landmarks else None)

            # ── Gap-fill ─────────────────────────────────────────────────────
            # Pass pose wrists so intentional hand-lowering is detected immediately
            pose_lm      = raw.get('pose')
            pose_wrist_l = pose_lm[15] if pose_lm and len(pose_lm) > 15 else None
            pose_wrist_r = pose_lm[16] if pose_lm and len(pose_lm) > 16 else None

            raw_left,  no_left  = fill_hand_gap(raw_left,  prev_left,  no_left,  MAX_GAP,
                                                pose_wrist=pose_wrist_l, w=w)
            raw_right, no_right = fill_hand_gap(raw_right, prev_right, no_right, MAX_GAP,
                                                pose_wrist=pose_wrist_r, w=w)

            raw['left_hand']  = raw_left
            raw['right_hand'] = raw_right

            # ── Temporal smoothing ───────────────────────────────────────────
            cur = smooth_landmarks(prev_lm, raw, alpha=0.5) if smooth else raw

            prev_lm    = cur
            prev_left  = cur.get('left_hand')
            prev_right = cur.get('right_hand')

            # ── Normalised copy ──────────────────────────────────────────────
            norm = center_and_scale(cur)

            # ── JSON record ──────────────────────────────────────────────────
            def to_list(lst):
                if lst is None:
                    return None
                return [{'x': float(p[0]), 'y': float(p[1]), 'z': float(p[2])}
                        for p in lst]

            all_frames.append({
                'frame_index':         frame_idx,
                'raw':                 {k: to_list(v) for k, v in raw.items()},
                'smoothed':            {k: to_list(v) for k, v in cur.items()},
                'normalized_centered': {k: to_list(v) for k, v in norm.items()},
            })

            # ── Draw skeleton ────────────────────────────────────────────────
            if draw_skeleton_frames:
                canvas   = draw_skeleton(w, h, cur,
                                         draw_face=draw_face,
                                         draw_inner_mouth=True)
                out_path = frames_dir / f"frame_{frame_idx:06d}.png"
                cv2.imwrite(str(out_path), canvas)
                print(f"  frame {frame_idx:05d}  "
                      f"L={raw_left is not None}  R={raw_right is not None}")

            frame_idx += 1

    cap.release()

    if save_json:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump({'video': name, 'fps': fps, 'width': w, 'height': h,
                       'frames': all_frames}, f, ensure_ascii=False)

    print(f"\n[DONE] {name}: {frame_idx} frames")
    print(f"       Frames -> {frames_dir}")
    print(f"       JSON   -> {json_path}")


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Extract MediaPipe Holistic landmarks and render skeleton frames.")
    ap.add_argument('--input_dir',     required=True,
                    help='Folder containing input videos.')
    ap.add_argument('--output_dir',    required=True,
                    help='Folder to write frames + JSON.')
    ap.add_argument('--draw_skeleton', action='store_true',
                    help='Save transparent PNG skeleton frames.')
    ap.add_argument('--save_json',     action='store_true',
                    help='Save landmarks JSON.')
    ap.add_argument('--smooth',        action='store_true',
                    help='Apply temporal smoothing.')
    ap.add_argument('--draw_face',     action='store_true',
                    help='Draw FaceMesh facial features.')
    args = ap.parse_args()

    exts   = {'.mp4', '.mov', '.avi', '.mkv', '.webm'}
    videos = [p for p in Path(args.input_dir).iterdir()
              if p.suffix.lower() in exts]

    if not videos:
        print("No video files found in", args.input_dir)
        return

    Path(args.output_dir).mkdir(parents=True, exist_ok=True)

    for v in videos:
        print(f"\n{'='*60}\nProcessing: {v.name}\n{'='*60}")
        process_video(
            v,
            args.output_dir,
            draw_skeleton_frames = args.draw_skeleton,
            save_json            = args.save_json,
            smooth               = args.smooth,
            draw_face            = args.draw_face,
        )

    print("\nAll done.")
    print("Assemble:  ffmpeg -framerate <FPS> -i frame_%06d.png "
          "-c:v libvpx-vp9 -pix_fmt yuva420p output.webm")


if __name__ == '__main__':
    main()