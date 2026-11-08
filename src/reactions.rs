pub const WINDOW_MS: u64 = 5_000;

pub fn strength(taps: u32) -> u8 {
    match taps {
        0 => 0,
        1..=2 => 1,
        3..=5 => 2,
        _ => 3,
    }
}

pub fn window_id(time: u64) -> u64 {
    time / WINDOW_MS
}

#[derive(Clone, Debug)]
pub struct Reaction {
    pub user_id: String,
    pub event_id: String,
    pub window: u64,
    pub taps: u32,
    pub last_tap: u64,
}

pub fn matches(a: &Reaction, b: &Reaction) -> bool {
    a.taps > 0
        && b.taps > 0
        && a.user_id != b.user_id
        && a.event_id == b.event_id
        && a.window == b.window
        && strength(a.taps).abs_diff(strength(b.taps)) <= 1
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn threshold_boundaries() {
        assert_eq!([0, 1, 2, 3, 5, 6, 80].map(strength), [0, 1, 1, 2, 2, 3, 3]);
    }
    #[test]
    fn fixed_windows() {
        assert_eq!(window_id(4999), 0);
        assert_eq!(window_id(5000), 1);
    }
    #[test]
    fn matching_conditions() {
        let a = Reaction {
            user_id: "a".into(),
            event_id: "live".into(),
            window: 1,
            taps: 1,
            last_tap: 0,
        };
        let mut b = Reaction {
            user_id: "b".into(),
            taps: 3,
            ..a.clone()
        };
        assert!(matches(&a, &b));
        b.taps = 6;
        assert!(!matches(&a, &b));
        b.taps = 0;
        assert!(!matches(&a, &b));
        b.taps = 3;
        b.window = 2;
        assert!(!matches(&a, &b));
        b.window = 1;
        b.event_id = "other".into();
        assert!(!matches(&a, &b));
        b.event_id = a.event_id.clone();
        b.user_id = a.user_id.clone();
        assert!(!matches(&a, &b));
    }
}
