use tokio::time::{sleep, Duration};

async fn compute() -> u8 {
    sleep(Duration::from_secs(1)).await;
    42
}

#[tokio::main]
async fn main() {
   println!("запустили compute");


    let handle = tokio::spawn(compute());
    
    println!("делаю что-то ещё пока compute работает...");
    
    // позже — дождаться и забрать результат
    let result = handle.await.unwrap();
    
    println!("результат: {}", result);
}
