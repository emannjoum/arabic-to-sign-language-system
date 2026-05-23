AVAILABLE_NUMBERS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 30, 40, 50, 60, 70, 80, 90,
    100, 200, 300, 400, 500, 600, 700, 800, 900,
    1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000,
    1000000, 1000000000,
    21, 32, 43, 65, 87, 99, 999, 9999
}

def parse_3_digits(n: int) -> list[str]:
    """to break down numbers up to 999 following Arabic reading rules."""
    res = []
    hundreds = (n // 100) * 100 #example: 900
    if hundreds > 0: res.append(str(hundreds))
    
    #Tens and Units (e.g., 75 -> 5 then 70)
    remainder = n % 100
    if remainder > 0:
        if remainder in AVAILABLE_NUMBERS: res.append(str(remainder))
        else:
            units = remainder % 10
            tens = (remainder // 10) * 10
            if units > 0: res.append(str(units))
            if tens > 0: res.append(str(tens))  
    return res

def break_down_number(n: int) -> list[str]:
    """to break a number into JSL DB components."""
    if n == 0: return ["0"]
        
    if n in AVAILABLE_NUMBERS: return [str(n)]

    parts = []
    billions = n // 1_000_000_000
    if billions > 0:
        if billions > 1: parts.extend(parse_3_digits(billions))
        parts.append("1000000000")
        n %= 1_000_000_000

    millions = n // 1_000_000
    if millions > 0:
        if millions > 1: parts.extend(parse_3_digits(millions))
        parts.append("1000000")
        n %= 1_000_000
        
    thousands = n // 1_000
    if thousands > 0:
        if thousands * 1000 in AVAILABLE_NUMBERS: parts.append(str(thousands * 1000))
        else:
            parts.extend(parse_3_digits(thousands))
            parts.append("1000")
        n %= 1_000
        
    if n > 0: parts.extend(parse_3_digits(n))
        
    return parts

def get_protected_number_sequence(token: str) -> list[str]:
    """Takes a number string (whole or decimal), returns a list of protected JSL tokens."""
    if '.' in token or '٫' in token or '،' in token:
        token = token.replace('٫', '.').replace('،', '.')
        left, right = token.split('.', 1)
        
        left_parts = break_down_number(int(left)) if left else ["0"]
        right_parts = break_down_number(int(right)) if right else ["0"]

        combined = left_parts + ["و"] + right_parts
        return [f"{n}_" for n in combined]
    
    broken_down = break_down_number(int(token))
    return [f"{n}_" for n in broken_down]