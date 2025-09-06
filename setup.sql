use logs; 
create table logs_history (alarm_creation_time datetime, CustomerID varchar(50), Number_of_invoice int);
select * from information_schema.tables where table_schema="logs";
select * from logs.logs_history order by Number_of_invoice desc; 

SELECT COUNT(*) FROM logs_history WHERE CustomerID = "";