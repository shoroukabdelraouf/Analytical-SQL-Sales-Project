Select * from TABLERETAIL;
--first question
--Q1- Using OnlineRetail dataset : write at least 5 analytical SQL queries that tells a story about the data 
--1) top 30 customers in buying.
    Select customer_id, sales
    from (Select customer_id, 
               sum(quantity * price) as SALES,
               DENSE_RANK() over (order by sum(quantity * PRICE) desc) as dr
                from TABLERETAIL
                group by customer_id) ranked_sales
    where dr <= 30;

--2)Top  15 Selling Products:
     Select STOCKCODE
    from ( Select STOCKCODE,
                        row_number() over (order by sum(QUANTITY) desc) AS RN
                  from TABLERETAIL
                  group by  STOCKCODE) 
      where RN <= 15;
      
--3) total revenue generated  each  month 

Select INVOICE_MONTH, MONTHLY_REVENUE
 from (Select   DISTINCT TO_CHAR(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'MM/YYYY') as INVOICE_MONTH,
                          sum(QUANTITY * PRICE) OVER (PARTITION BY TO_CHAR(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'MM/YYYY')) as MONTHLY_REVENUE,
                          TO_CHAR(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'YYYY') as YEAR,
                          TO_CHAR(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'MM') as MONTH
             from  TABLERETAIL )
              order by YEAR, MONTH;

-- 4)total revenue generated  each quarter
Select 
    distinct to_char(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'YYYY') as INVOICE_YEAR,
    'Q'||to_char(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'Q') as QUARTER,
    sum(quantity * price) over (partition by to_char(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'YYYY'), to_char(TO_DATE(INVOICEDATE, 'MM/DD/YYYY HH24:MI'), 'Q')) as QUARTERLY_REVENUE
from TABLERETAIL
order by INVOICE_YEAR, QUARTER;
    
   --5)total revenue  per product
  Select  distinct STOCKCODE,
            sum(QUANTITY * PRICE) over(partition by STOCKCODE) as rev_per_product
   from TABLERETAIL
  order by  STOCKCODE;
 ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 --Q2- After exploring the data now you are required to implement a Monetary model for customers behavior for product purchasing and segment each customer based on the below groups 
--ri :
--returns for each customer his recency, frequency, and the monetary value.
--r2:
--Assigning Segment Scores
--assigns a score (1-5) based on recency, with 5 being the most recent.
--assigns a score (1-5) based on purchase frequency, with 5 being the most frequent buyer.
--assigns a score (1-5) based on total spending, with 5 being the highest spender.
--r3:
--the average of the f_score (frequency score) and m_score (monetary score) and then round it to the nearest whole number.
 --   Final sselect :
--Based on the recency and fm score , assigns each customer to a segment based on their purchase behaviour.

with r1 as(
        select distinct customer_id,
                  round( (select  max(to_date(invoicedate,'MM/DD/YYYY HH24:MI')) from TABLERETAIL) - max(to_date(invoicedate,'MM/DD/YYYY HH24:MI')) over(partition by customer_id),0) as recency,
                  count(*) over(partition by customer_id) as frequency,
                  round ( (sum(quantity*price) over(partition by customer_id) )/1000,2)as Monetary
                   from TABLERETAIL
              ),
      r2 as (
       select distinct customer_id,frequency,Monetary, recency,
                            ntile(5)over(order by recency desc) as r_score, --assigns a score (1-5) based on recency, with 5 being the most recent
                            ntile(5)over(order by frequency ) as f_score, --assigns a score (1-5) based on purchase frequency, with 5 being the most frequent buyer
                            ntile(5)over(order by Monetary ) as m_score    -- assigns a score (1-5) based on total spending, with 5 being the highest spender         
          from r1
              ),
        r3 as (--
                    select distinct customer_id,frequency,Monetary, recency,r_score,
                             f_score,m_score,round((f_score + m_score) / 2, 0) as fm_score
                from r2
              )
              
     select customer_id,recency,frequency,Monetary,r_score, fm_score,
               case when (r_score=5 and fm_score=5) or (r_score=4 and fm_score=5)or(r_score=5 and fm_score=4 ) then'champions'
                      when(r_score=5 and fm_score=2)or(r_score=4 and fm_score=2)or( r_score=3 and fm_score=3)or (r_score=4 and fm_score=3)then'potential loyalists'
                      when (r_score=5 and fm_score=3) or(r_score=4 and fm_score=4) or  (r_score=3 and fm_score=5)or (r_score=3 and fm_score=4) then 'loyal customer'
                      when (r_score=5 and fm_score=1) then 'recent customer'
                      when  (r_score=4 and fm_score=1)or(r_score=3 and fm_score=1)then 'promising'
                      when  (r_score=3 and fm_score=2)or (r_score=2 and fm_score=3)or (r_score=2 and fm_score=2) then'customers needing attention'
                      when  (r_score=2 and fm_score=5)or (r_score=2 and fm_score=4)or (r_score=1and fm_score=3) then'at risk'
                      when (r_score=1 and fm_score=4)or (r_score=1and fm_score=5) then'can not lose them'
                      when  (r_score=1 and fm_score=2) or  (r_score=2 and fm_score=1) then 'hibernating'
                      when  (r_score=1 and fm_score=1) then'lost'
                       end customer_segement
                       from r3;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--question3:
select * from daily_tra where cust_id = 1073321 order by calendar_dt;
  --1) What is the maximum number of consecutive days a customer made purchases? 
    --r2:
  --It assigns a group (grp) to the consecutive days based on the calculated differences. 
 -- If the difference between consecutive days is 1 or null, it treats them as part of the same group   otherwise, it starts a new group.
-- r3:
 -- This counts the consecutive days of the purchase for each customer in the same group.
 --final query:
--It calculates the maximum consecutive days of purchases (max_consecutive_days) for each customer using the MAX function over the num column, which represents the count of consecutive days in each group.
  

 
    with r1 as( 
             select cust_id,calendar_dt,
                  row_number()over(partition by cust_id order by calendar_dt)as RN,
                  calendar_dt - lag(calendar_dt,1) over(partition by cust_id order by calendar_dt) as difference
                  from daily_tra 
                   ),
                   r2 as (
                   select cust_id,calendar_dt,rn,difference,
                   sum(case when difference=1 or difference is null then 0 else 1 end ) over ( partition by cust_id order by rn) as grp
                   from r1
                   ),
                   r3 as (
                   select cust_id,calendar_dt,rn,difference,grp,
                   count(*) over(partition by cust_id,grp ) as num
                   from r2 
                   )
select distinct cust_id,
    max(num) over (partition by cust_id ) as max_consecutive_days
    from r3 ;
        
 --2) On average, How many days/transactions does it take a customer to reach a spent threshold of 250 L.E? 
 --R1:
--It returns the running total of amt_le for each customer by grouping by cust_id and ordering by calendar_dt. 
--It also assigns a row number (within each customer's data) 
--R2:
-- keep rows where the difference between total_amount and amt_le is less than 250.
 --It then calculates the maximum total_amount reached for each customer.
--R3:
--keeping only rows where max_amount is greater than or equal to 250. Then we will get the count of   customers who had a running total exceeding the threshold .
--Finally:
-- it calculates the count of days for each customer that met the condition in  r3

 
with r1 as (
                 
                      SELECT  cust_id, calendar_dt,amt_le,
                                SUM(amt_le) OVER (PARTITION BY cust_id ORDER BY calendar_dt) AS total_amount,
                                ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY calendar_dt) AS RN
                            FROM  daily_tra
                    ),
                    r2 as (
                    select cust_id, calendar_dt,amt_le, total_amount, 
                    max (total_amount) over (partition by cust_id) as max_amount
                    from r1
                    where total_amount - amt_le < 250              
                    ),
                    r3 as (  
                    select cust_id, calendar_dt,amt_le, total_amount,
                    count(*) over (partition by cust_id) as c
                    from r2
                    where max_amount >= 250
                    )
select  round(avg(c)) as days
from r3 ;

                  



















