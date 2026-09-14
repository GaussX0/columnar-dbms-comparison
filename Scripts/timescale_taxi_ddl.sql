CREATE TABLE taxis (
    VendorID INTEGER,
    tpep_pickup_datetime TIMESTAMPTZ,
    tpep_dropoff_datetime TIMESTAMPTZ,
    passenger_count INTEGER,
    trip_distance DECIMAL(10, 2),
    RatecodeID INTEGER,
    store_and_fwd_flag TEXT,
    PULocationID INTEGER,
    DOLocationID INTEGER,
    payment_type INTEGER,
    fare_amount DECIMAL(10, 2),
    extra DECIMAL(10, 2),
    mta_tax DECIMAL(10, 2),
    tip_amount DECIMAL(10, 2),
    tolls_amount DECIMAL(10, 2),
    improvement_surcharge DECIMAL(10, 2),
    total_amount DECIMAL(10, 2)
);

SELECT create_hypertable('taxis', 'tpep_pickup_datetime');

ALTER TABLE taxis SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'VendorID'
);
