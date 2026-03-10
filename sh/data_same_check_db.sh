#!/bin/bash

DB="wordpress"

OUTPUT="db_verify_$(date +%F_%H-%M-%S).txt"

echo "===== Database Verification Report =====" | tee $OUTPUT
echo "Database: $DB" | tee -a $OUTPUT
echo "Time: $(date)" | tee -a $OUTPUT
echo "" | tee -a $OUTPUT

# 获取所有表
tables=$(mysql -N -e "
SELECT table_name
FROM information_schema.tables
WHERE table_schema='$DB';
")

echo "Table | Rows | Checksum" | tee -a $OUTPUT
echo "----------------------------------------" | tee -a $OUTPUT

for table in $tables
do
    # 获取行数
    rows=$(mysql -h$HOST -u$USER -p$PASS -N -e "
    SELECT COUNT(*) FROM $DB.$table;
    ")

    # 获取 checksum
    checksum=$(mysql -h$HOST -u$USER -p$PASS -N -e "
    CHECKSUM TABLE $DB.$table;
    " | awk '{print $2}')

    printf "%-30s %-10s %-20s\n" "$table" "$rows" "$checksum" | tee -a $OUTPUT

done

echo "" | tee -a $OUTPUT
echo "Verification finished." | tee -a $OUTPUT
echo "Report saved: $OUTPUT"
