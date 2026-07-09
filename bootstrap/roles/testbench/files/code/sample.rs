//! Module doc comment.
use std::collections::HashMap;

const MAX: u32 = 10;

#[derive(Debug)]
struct User<'a> {
    id: u64,
    name: &'a str,
}

impl<'a> User<'a> {
    fn greet(&self, times: usize) -> String {
        // TODO: builtins, operators
        let mut out = String::new();
        for _ in 0..times.min(MAX as usize) {
            out.push_str(&format!("hi {}\n", self.name));
        }
        out
    }
}
