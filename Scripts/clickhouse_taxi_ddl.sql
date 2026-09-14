CREATE TABLE taxis (
    VendorID Int32, 
    tpep_pickup_datetime DateTime, 
    tpep_dropoff_datetime DateTime, 
    passenger_count Int32, 
    trip_distance Float32, 
    RatecodeID Int32, 
    store_and_fwd_flag String, 
    PULocationID Int32, 
    DOLocationID Int32, 
    payment_type Int32, 
    fare_amount Float32, 
    extra Float32, 
    mta_tax Float32, 
    tip_amount Float32, 
    tolls_amount Float32, 
    improvement_surcharge Float32, 
    total_amount Float32 
) ENGINE = MergeTree()
ORDER BY (VendorID, tpep_pickup_datetime);
