// Rust test fixture
const VERSION: &str = "1.0.0";

pub struct Point {
    x: f64,
    y: f64,
}

impl Point {
    pub fn new(x: f64, y: f64) -> Self {
        Point { x, y }
    }
    
    pub fn distance(&self, other: &Point) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }
}

trait Drawable {
    fn draw(&self);
}

impl Drawable for Point {
    fn draw(&self) {
        println!("Point at ({}, {})", self.x, self.y);
    }
}

enum Status {
    Ok,
    Error(String),
}

fn add(a: i32, b: i32) -> i32 {
    a + b
}

mod utils {
    pub fn format(s: &str) -> String {
        s.trim().to_string()
    }
}

type Result<T> = std::result::Result<T, String>;

static GLOBAL_CONFIG: &str = "default";

macro_rules! debug_print {
    ($($arg:tt)*) => {
        println!("DEBUG: {}", format!($($arg)*));
    };
}

pub fn main() {
    println!("Hello, Rust!");
}