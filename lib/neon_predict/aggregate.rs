use rustler::NifMap;
use ta::{Open, Close, Low, High, Volume};

#[derive(Debug, NifMap)]
pub struct Aggregate {
    open_price: f64,
    high_price: f64,
    low_price: f64,
    close_price: f64,
    volume: u64,

    timestamp: u64,
}

impl Open for Aggregate {
    fn open(&self) -> f64 {
        return self.open_price
    }
}

impl High for Aggregate {
    fn high(&self) -> f64 {
        return self.high_price
    }
}

impl Low for Aggregate {
    fn low(&self) -> f64 {
        return self.low_price
    }
}

impl Close for Aggregate {
    fn close(&self) -> f64 {
        return self.close_price
    }
}

impl Volume for Aggregate {
    fn volume(&self) -> f64 {
        return self.volume as f64
    }
}
