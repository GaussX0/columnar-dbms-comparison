CREATE TABLE taxis (
	`VendorID` DECIMAL(38, 0) NOT NULL, 
	tpep_pickup_datetime DATETIME NULL, 
	tpep_dropoff_datetime DATETIME NULL, 
	passenger_count DECIMAL(38, 0), 
	trip_distance DECIMAL(38, 2) NOT NULL, 
	`RatecodeID` DECIMAL(38, 0), 
	store_and_fwd_flag CHAR(1), 
	`PULocationID` DECIMAL(38, 0) NOT NULL, 
	`DOLocationID` DECIMAL(38, 0) NOT NULL, 
	payment_type DECIMAL(38, 0) NOT NULL, 
	fare_amount DECIMAL(38, 2) NOT NULL, 
	extra DECIMAL(38, 2) NOT NULL, 
	mta_tax DECIMAL(38, 2) NOT NULL, 
	tip_amount DECIMAL(38, 2) NOT NULL, 
	tolls_amount DECIMAL(38, 2) NOT NULL, 
	improvement_surcharge DECIMAL(38, 1) NOT NULL, 
	total_amount DECIMAL(38, 2) NOT NULL 
) ENGINE=columnstore;

-- original header: VendorID,tpep_pickup_datetime,tpep_dropoff_datetime,passenger_count,trip_distance,RatecodeID,store_and_fwd_flag,PULocationID,DOLocationID,payment_type,fare_amount,extra,mta_tax,tip_amount,tolls_amount,improvement_surcharge,total_amount
