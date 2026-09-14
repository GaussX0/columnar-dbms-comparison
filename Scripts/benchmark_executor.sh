#!/bin/bash

#### DB CHOICE
# Choose one, or use "ALL" to iterate through every database sequentially
# DATABASE="ALL"
DATABASE="clickhouse"
# DATABASE="duckdb"
# DATABASE="monetdb"
# DATABASE="mariadb"
# DATABASE="timescaledb"

#### BENCHMARK BASIS
# "TAXIS" uses the hardcoded standard queries
# "TPC" loads engine-specific files from queries/{DB_NAME}/{QUERY}.sql
BENCHMARK_BASIS="TAXIS"

#### TEST CHOICE
# Choosing "COLD" causes the target servers to be restarted between query runs, as well as empties system caches. 
# choose "HOT" to skip restarting the server.
# Note: Because DuckDB is a process, every query run is a new process, DuckDB will always operate in "COLD" mode.
TEST_CHOICE="COLD"

#### QUERY CHOICE
# Set to 1-10 for TAXIS, or 1-22 for TPC
QUERY="8"

#### EXECUTION MODE
# "SINGLE" prints directly to terminal once
# "BENCHMARK" runs it ITERATIONS times and formats the results into a text file
EXEC_MODE="BENCHMARK"
ITERATIONS=50
OUTPUT_FILE="${BENCHMARK_BASIS}_${QUERY}_benchmark_results.txt"

if [ "$DATABASE" == "ALL" ]; then
    DATABASES_TO_RUN=("clickhouse" "duckdb" "mariadb" "monetdb" "timescaledb") 
else
    DATABASES_TO_RUN=("$DATABASE")
fi

if [ "$EXEC_MODE" == "BENCHMARK" ]; then
    > "$OUTPUT_FILE"
    echo "Starting BENCHMARK mode ($ITERATIONS runs per DB). Outputting to $OUTPUT_FILE..."
fi

for DB in "${DATABASES_TO_RUN[@]}"; do
    echo "======================================"
    echo "Target Database: $DB"

    if [ "$BENCHMARK_BASIS" == "TAXIS" ]; then
	MODE="standard"
        case "$QUERY" in
            "1") SQL_CMD="SELECT SUM(total_amount) AS total_revenue, AVG(trip_distance) AS avg_distance, COUNT(*) AS total_trips FROM taxis;" ;;
            "2") SQL_CMD="SELECT payment_type, passenger_count, COUNT(*) AS trip_count FROM taxis GROUP BY payment_type, passenger_count ORDER BY trip_count DESC;" ;;
            "3") SQL_CMD="SELECT PULocationID, DOLocationID, CAST(tpep_pickup_datetime AS DATE) AS pickup_date, SUM(fare_amount) AS daily_route_revenue FROM taxis GROUP BY PULocationID, DOLocationID, CAST(tpep_pickup_datetime AS DATE) ORDER BY daily_route_revenue DESC LIMIT 100;" ;;
            "4") SQL_CMD="SELECT * FROM taxis ORDER BY trip_distance DESC LIMIT 100;" ;;
            "5") SQL_CMD="SELECT * FROM taxis WHERE total_amount > 500 AND passenger_count = 5;" ;;
            "6") SQL_CMD="SELECT EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour, COUNT(*) AS total_trips, AVG(trip_distance) AS avg_distance FROM taxis WHERE tpep_pickup_datetime >= '2018-10-01 00:00:00' AND tpep_pickup_datetime < '2018-11-01 00:00:00' GROUP BY EXTRACT(HOUR FROM tpep_pickup_datetime) ORDER BY pickup_hour;" ;;
            "7") SQL_CMD="SELECT PULocationID, tpep_pickup_datetime, fare_amount, SUM(fare_amount) OVER (PARTITION BY PULocationID ORDER BY tpep_pickup_datetime) AS running_location_revenue FROM taxis ORDER BY PULocationID, tpep_pickup_datetime LIMIT 10000;" ;;
	    "8") SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, tpep_pickup_datetime + INTERVAL '3 years', tpep_dropoff_datetime + INTERVAL '3 years', passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
		 MODE="insert";;
	    "9") SQL_CMD="UPDATE taxis SET improvement_surcharge = 1.0 WHERE passenger_count > 4 AND trip_distance > 50 AND tpep_pickup_datetime > '2020-12-31 00:00:00'"
		 MODE="update" ;;
            "10") SQL_CMD="DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'"
		 MODE="delete" ;;
            *) echo "Invalid Query Choice."; exit 1 ;;
        esac
    elif [ "$BENCHMARK_BASIS" == "TPC" ]; then
        SQL_FILE="queries/${DB}/query_${QUERY}.sql"
        if [ ! -f "$SQL_FILE" ]; then
            echo "Error: TPC file $SQL_FILE not found! Skipping $DB..."
            continue
        fi
	# SQL_CMD=$(sed 's/--.*//g' "$SQL_FILE" | sed 's/limit -1//Ig' | tr '\n' ' ' | tr '[:lower:]' '[:upper:]' | sed 's/"/\\"/g')
	SQL_CMD=$(sed 's/--.*//g' "$SQL_FILE" | sed 's/limit -1//Ig' | tr '\n' ' ' | sed 's/"/\\"/g')
    else
        echo "Invalid BENCHMARK_BASIS. Must be 'TAXIS' or 'TPC'."
        exit 1
    fi

    case "$DB" in
        "clickhouse")
            DB_PROCESSES="clickhouse"
            # QUERY_CMD="clickhousectl local client --database=default --time --query \"$SQL_CMD\""
	    QUERY_CMD="clickhousectl local client --database=default --time \
		    --max_bytes_before_external_group_by=22G \
        	    --max_bytes_before_external_sort=22G \
		    --query \"$SQL_CMD\""
	    if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
		HELPER_SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, addYears(tpep_pickup_datetime, 3), addYears(tpep_dropoff_datetime, 3), passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
	        HELPER_INSERT_CMD="clickhousectl local client --database=default --time \
		    --max_bytes_before_external_group_by=22G \
        	    --max_bytes_before_external_sort=22G \
		    --query \"$HELPER_SQL_CMD\""
	        HELPER_DELETE_CMD="clickhousectl local client --database=default --time \
		    --max_bytes_before_external_group_by=22G \
        	    --max_bytes_before_external_sort=22G \
                    --query \"DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'\""
	    fi
            ;;
        "duckdb")
            DB_PROCESSES="duckdb"
	    if [ $BENCHMARK_BASIS == "TPC" ]; then
		FILE="tpch.duckdb"
	    else
		FILE="thesis.duckdb"
	    fi
	    QUERY_CMD="duckdb $FILE -c '.timer on' -c \"$SQL_CMD\""
	    if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
	        HELPER_SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, tpep_pickup_datetime + INTERVAL '3 years', tpep_dropoff_datetime + INTERVAL '3 years', passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
	        HELPER_INSERT_CMD="duckdb $FILE -c '.timer on' -c \"$HELPER_SQL_CMD\""
	        HELPER_DELETE_CMD="duckdb $FILE -c '.timer on' -c \"DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'\""
	    fi
            ;;
        "monetdb")
            DB_PROCESSES="mserver5"
	    if [ "$MODE" == "insert" ]; then
		SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, tpep_pickup_datetime + INTERVAL '3-0' YEAR TO MONTH, tpep_dropoff_datetime + INTERVAL '3-0' YEAR TO MONTH, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
	    fi 
            QUERY_CMD="sudo mclient -d thesis -t performance -s \"$SQL_CMD\""
	    if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
	        HELPER_SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, tpep_pickup_datetime + INTERVAL '3 years', tpep_dropoff_datetime + INTERVAL '3 years', passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
                HELPER_INSERT_CMD="sudo mclient -d thesis -t performance -s \"$HELPER_SQL_CMD\""
                HELPER_DELETE_CMD="sudo mclient -d thesis -t performance -s \"DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'\""
	    fi
            ;;
        "mariadb")
            DB_PROCESSES="mariadbd|PrimProc|ExeMgr"
	    if [ "$MODE" == "insert" ]; then
		SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, DATE_ADD(tpep_pickup_datetime, INTERVAL 3 YEAR), DATE_ADD(tpep_dropoff_datetime, INTERVAL 3 YEAR), passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
	    fi 
            QUERY_CMD="mariadb -u root --password=qwerty -vvv -D thesis -e \"$SQL_CMD\""
	    if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
		HELPER_SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, DATE_ADD(tpep_pickup_datetime, INTERVAL 3 YEAR), DATE_ADD(tpep_dropoff_datetime, INTERVAL 3 YEAR), passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
                HELPER_INSERT_CMD="mariadb -u root --password=qwerty -vvv -D thesis -e \"$HELPER_SQL_CMD\""
                HELPER_DELETE_CMD="mariadb -u root --password=qwerty -vvv -D thesis -e \"DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'\""
	    fi
            ;;
        "timescaledb")
            DB_PROCESSES="postgres"
            QUERY_CMD="psql -d thesis -c '\timing' -c \"$SQL_CMD\""
	    if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
	        HELPER_SQL_CMD="INSERT INTO taxis (VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount) select VendorID, tpep_pickup_datetime + INTERVAL '3 years', tpep_dropoff_datetime + INTERVAL '3 years', passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount from taxis where tpep_pickup_datetime <= '2018-02-01 00:00:00' and tpep_pickup_datetime < '2018-03-01 00:00:00';"
                HELPER_INSERT_CMD="psql -d thesis -c '\timing' -c \"$HELPER_SQL_CMD\""
                HELPER_DELETE_CMD="psql -d thesis -c '\timing' -c \"DELETE FROM taxis WHERE (trip_distance <= 10 OR fare_amount <= 0) AND tpep_pickup_datetime > '2020-12-31 00:00:00'\""
	    fi
            ;;
    esac

    arr_times=()
    arr_rams=()
    arr_ops=()
    arr_vols=()

    if [ "$EXEC_MODE" == "BENCHMARK" ]; then RUNS=$ITERATIONS; else RUNS=1; fi

    for (( i=1; i<=RUNS; i++ )); do
        if [ "$EXEC_MODE" == "BENCHMARK" ]; then echo -n "  Run $i/$RUNS for $DB... "; fi
	if [ "$MODE" == "update" ] || [ "$MODE" == "delete" ]; then
            eval "$HELPER_INSERT_CMD" > /dev/null 2>&1
	fi

        if [ "$TEST_CHOICE" == "COLD" ]; then
            case "$DB" in
                "clickhouse")
                    clickhousectl local server stop default > /dev/null 2>&1
                    sudo sysctl vm.drop_caches=3 > /dev/null 2>&1
                    clickhousectl local server start > /dev/null 2>&1
                    while ! clickhousectl local client --query "SELECT 1" &> /dev/null; do sleep 0.5; done
                    ;;
                "duckdb")
                    sudo sysctl vm.drop_caches=3 > /dev/null 2>&1
                    ;;
                "monetdb")
                    sudo systemctl stop monetdbd > /dev/null 2>&1
                    sudo sysctl vm.drop_caches=3 > /dev/null 2>&1
                    sudo systemctl start monetdbd > /dev/null 2>&1
                    sudo monetdb start thesis
                    ;;
                "mariadb")
                    sudo systemctl stop mariadb > /dev/null 2>&1
                    sudo systemctl stop mariadb-columnstore > /dev/null 2>&1
                    sudo sysctl vm.drop_caches=3 > /dev/null 2>&1
                    sudo systemctl start mariadb-columnstore > /dev/null 2>&1
                    sudo systemctl start mariadb > /dev/null 2>&1
                    ;;
                "timescaledb")
                    sudo systemctl stop postgresql > /dev/null 2>&1
                    sudo sysctl vm.drop_caches=3 > /dev/null 2>&1
                    sudo systemctl start postgresql > /dev/null 2>&1
                    ;;
            esac
        fi
        SECTORS_BEFORE=$(awk '{s+=$6} END {print s}' /proc/diskstats)
        READ_OPS_BEFORE=$(awk '{s+=$4} END {print s}' /proc/diskstats)
        > memory_log.txt

        #(
        #  while true; do
        #    PIDS=$(pgrep -d ',' "$DB_PROCESSES")
        #    # if [ ! -z "$PIDS" ]; then ps -p $PIDS -o rss= | awk '{s+=$1} END {print s}' >> memory_log.txt; fi
	#    if [ ! -z "$PIDS" ]; then
        #      cat /proc/$PIDS/smaps_rollup 2>/dev/null | grep -i "^Pss:" | awk '{s+=$2} END {print s}' >> memory_log.txt
        #    fi
        #    sleep 0.1
        #  done
        #) & 
        #MONITOR_PID=$!

	(
          sudo bash -c "
            while true; do
              # Get space-separated PIDs (removed -d ',')
              PIDS=\$(pgrep '$DB_PROCESSES')
              if [ -n \"\$PIDS\" ]; then
                # Loop through each PID to construct valid, individual file paths
                for PID in \$PIDS; do
                  cat /proc/\$PID/smaps_rollup 2>/dev/null
                done | grep -i '^Pss:' | awk '{s+=\$2} END {print s}' >> memory_log.txt
              fi
              sleep 0.1
            done
          "
        ) &
        MONITOR_PID=$!

        START_TIME=$(date +%s.%N)
        if [ "$EXEC_MODE" == "BENCHMARK" ]; then
            eval "$QUERY_CMD" > /dev/null 2>&1
        else
            eval "$QUERY_CMD"
        fi
        END_TIME=$(date +%s.%N)

        kill $MONITOR_PID 2>/dev/null
        SECTORS_AFTER=$(awk '{s+=$6} END {print s}' /proc/diskstats)
        READ_OPS_AFTER=$(awk '{s+=$4} END {print s}' /proc/diskstats)

        RAW_TIME=$(echo "$END_TIME - $START_TIME" | bc)
        EXEC_TIME=$(printf "%.3f" $RAW_TIME)

        PEAK_KB=$(sort -n memory_log.txt | tail -n 1)
        if [ -z "$PEAK_KB" ]; then PEAK_KB=0; fi
        PEAK_MB=$(echo "scale=2; $PEAK_KB / 1024" | bc)

        SECTORS_DIFF=$((SECTORS_AFTER - SECTORS_BEFORE))
        BYTES_READ=$((SECTORS_DIFF * 512))
        MB_READ=$(echo "scale=2; $BYTES_READ / 1048576" | bc)

        READ_OPS_DIFF=$((READ_OPS_AFTER - READ_OPS_BEFORE))

        rm memory_log.txt

        if [ "$EXEC_MODE" == "BENCHMARK" ]; then
            echo "Done (${EXEC_TIME}s)"
            arr_times+=("$EXEC_TIME")
            arr_rams+=("$PEAK_MB")
            arr_ops+=("$READ_OPS_DIFF")
            arr_vols+=("$MB_READ")
        else
            echo "----------------------------------------"
            echo "UNIVERSAL HARDWARE METRICS:"
            echo "Execution Time : $EXEC_TIME seconds"
            echo "Peak RAM Usage : $PEAK_MB MB"
            echo "Disk Accesses  : $READ_OPS_DIFF operations"
            echo "Disk Volume    : $MB_READ MB"
            echo "----------------------------------------"
        fi
	if [ "$MODE" == "insert" ] || [ "$MODE" == "update" ]; then
            eval "$HELPER_DELETE_CMD" > /dev/null 2>&1
	fi
    done

    if [ "$EXEC_MODE" == "BENCHMARK" ]; then
        AVG_TIME=$(echo "${arr_times[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; if(NF>0) print sum/NF; else print 0}')
        AVG_TIME=$(printf "%.3f" "$AVG_TIME")
        
        AVG_RAM=$(echo "${arr_rams[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; if(NF>0) print sum/NF; else print 0}')
        AVG_RAM=$(printf "%.2f" "$AVG_RAM")
        
        AVG_OPS=$(echo "${arr_ops[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; if(NF>0) print sum/NF; else print 0}')
        AVG_OPS=$(printf "%.0f" "$AVG_OPS")
        
        AVG_VOL=$(echo "${arr_vols[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; if(NF>0) print sum/NF; else print 0}')
        AVG_VOL=$(printf "%.2f" "$AVG_VOL")

        STR_TIMES=$(echo "${arr_times[@]}" | sed 's/ /, /g')
        STR_RAMS=$(echo "${arr_rams[@]}" | sed 's/ /, /g')
        STR_OPS=$(echo "${arr_ops[@]}" | sed 's/ /, /g')
        STR_VOLS=$(echo "${arr_vols[@]}" | sed 's/ /, /g')

        {
            echo "Database: $DB"
            echo "Query: $QUERY_CMD"
            echo "Execution Times: $STR_TIMES"
            echo "RAM Usage: $STR_RAMS"
            echo "Disk Operations: $STR_OPS"
            echo "Disk Volume: $STR_VOLS"
            echo "Averages: Execution Time: ${AVG_TIME}s, RAM: ${AVG_RAM}MB, Disk Ops: ${AVG_OPS}, Disk Vol: ${AVG_VOL}MB"
            echo "--------------------------------------------------------------------------------"
        } >> "$OUTPUT_FILE"
        
        echo "Results for $DB written to $OUTPUT_FILE."
    fi
done
