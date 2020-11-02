mod aggregate;

use crate::aggregate::Aggregate;
use ta::indicators::SimpleMovingAverage;
use ta::Next;

#[rustler::nif]
fn predict_stock(data: Vec<Aggregate>) -> f64 {
    return moving_average(data, 3);
}

fn moving_average(data: Vec<Aggregate>, len: u32) -> f64 {
    let mut ema = SimpleMovingAverage::new(len).unwrap();
    let mut res: f64 = 0.0;

    for d in data[data.len() - len as usize..data.len()].into_iter() {
        res = ema.next(d);
    }

    return res;
}

rustler::init!("Elixir.NeonPredict", [predict_stock]);
