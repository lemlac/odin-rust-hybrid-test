#[unsafe(no_mangle)]
pub extern "C" fn add(left: f32, right: f32) -> f32 {
    left + right
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2.0f32, 2.0f32);
        assert_eq!(result, 4.0f32);
    }
}
