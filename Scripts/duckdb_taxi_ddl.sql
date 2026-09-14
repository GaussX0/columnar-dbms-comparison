CREATE TABLE taxis (
    VendorID INTEGER NOT NULL, 
    tpep_pickup_datetime TIMESTAMP, 
    tpep_dropoff_datetime TIMESTAMP, 
    passenger_count INTEGER, 
    trip_distance DECIMAL(10, 2) NOT NULL, 
    RatecodeID INTEGER, 
    store_and_fwd_flag VARCHAR, 
    PULocationID INTEGER NOT NULL, 
    DOLocationID INTEGER NOT NULL, 
    payment_type INTEGER NOT NULL, 
    fare_amount DECIMAL(10, 2) NOT NULL, 
    extra DECIMAL(10, 2) NOT NULL, 
    mta_tax DECIMAL(10, 2) NOT NULL, 
    tip_amount DECIMAL(10, 2) NOT NULL, 
    tolls_amount DECIMAL(10, 2) NOT NULL, 
    improvement_surcharge DECIMAL(10, 2) NOT NULL, 
    total_amount DECIMAL(10, 2) NOT NULL 
);
