DECLARE @Membership TABLE (  
    PersonID int,Surname nvarchar(16),FirstName nvarchar(16),  
    Description nvarchar(16),StartDate datetime,EndDate datetime)   
INSERT INTO @Membership 
VALUES (18, 'Smith', 'John','Poker Club', '2019-01-01', NULL) 
INSERT INTO @Membership 
VALUES (18, 'Smith', 'John','Library', '2019-02-05', '2019-04-18') 
INSERT INTO @Membership 
VALUES (18, 'Smith', 'John','Gym', '2019-03-10', '2019-05-28') 
INSERT INTO @Membership 
VALUES (26, 'Adams', 'Jane','Pilates', '2019-01-03', '2019-05-16')
INSERT INTO @Membership 
VALUES (26, 'Adams', 'Jane','Gym', '2019-03-03', '2019-04-16')
--------
----------------------
----------------------
--Adding several columns for analyzing
if OBJECT_ID('tempdb..#Membership') is not null drop table #Membership
Select *, 
DATEDIFF(d,'2019-01-01',StartDate) as startDt#,
DateDiff(d,'2019-01-01',isnull(EndDate,getdate())) as endDt#,
ROW_NUMBER()over(partition by PersonID order by StartDate) as Row#,
ROW_NUMBER()over(order by StartDate) as Row#1,
case	when EndDate is null 
			then GETDATE() 
		else EndDate end  EndDate1, -----**
case	
		when EndDate>lead(StartDate) over (partition by PersonID order by PersonID, StartDate)
			then dateadd(d,-1,lead(StartDate) over (partition by PersonID order by PersonID, StartDate))
		else EndDate end  EndDate2 -----**
--
into #Membership
from @Membership
--select * from #Membership

----------------------
----------------------
----------------------
---Trying to get the correct start/end date 
if OBJECT_ID('tempdb..#Membership1') is not null drop table #Membership1
Select PersonID,
Surname,
FirstName, 
startDate,
case 
	when EndDate1>lead(StartDate) over (partition by PersonID order by Row#)
		then dateadd(d,-1,lead(StartDate) over (partition by PersonID order by Row#))
	else EndDate1 end as testDate2
into  #Membership1
from #Membership
---Select * from #Membership1
if OBJECT_ID('tempdb..#Membership2') is not null drop table #Membership2
Select a.*
into #Membership2
From 
(
	Select PersonID,
	Surname,
	FirstName,
	startDate,
	case	
		when EndDate1>lag(EndDate) over (partition by PersonID order by Row#)
			then lag(EndDate)over (partition by PersonID order by Row#)
		else null end as testDate2
	From #Membership 
	)a
where a.testDate2 is not null
--select * From #Membership2 
if OBJECT_ID('tempdb..#Membership3') is not null drop table #Membership3
Select distinct PersonID,Surname,FirstName,
case 
	when max(StartDate)over (partition by PersonID) < max(EndDate2) over(partition by PersonID)
		then dateadd(d,1, max(EndDate2) over(partition by PersonID))
		end as startDate,
max(EndDate1)over(partition by PersonID) as Test1
into #Membership3
From #Membership
--select * From #Membership3
if OBJECT_ID('tempdb..#TotalMembership') is not null drop table #TotalMembership
Select * into #TotalMembership  From #Membership1
union all
Select * From #Membership2
union all
Select * From #Membership3

order by PersonID, testDate2
--select * From #TotalMembership
----------------------
----------------------
----------------------
----------------------
----------------------
if OBJECT_ID('tempdb..#Test') is not null drop table #Test
select a.personid,a.surname,a.firstname,
case
	when dateadd(d,-1,a.startDate)<>lag(a.testDate2) over (partition by a.PersonID order by a.PersonID, a.testDate2)
		then cast(dateadd(d,1, lag(a.testDate2) over (partition by a.PersonID order by a.PersonID, a.testDate2)) as date)
	else cast(a.StartDate as date)
		end as startDate,
case	
	when cast(a.testdate2 as date) = cast(getdate() as date) --changing today back to null
		then null 
	else cast(a.testdate2 as date)
		end as enddate
into #test
From #TotalMembership a left join #Membership b on a. startDate = b.startDate

--select * from #test
----------------------
----------------------
--------Adding Day#--------
if OBJECT_ID('tempdb..#Test1') is not null drop table #Test1
Select *, 
DATEDIFF(d,'2019-01-01',StartDate) as startDt#,
DateDiff(d,'2019-01-01',isnull(EndDate,getdate())) as endDt#
into #Test1
From #test
--select * from #test1

----------------------
----------------------
---Create table that contains each day of the events, from begin date of the event to the end date of the event 
if OBJECT_ID('tempdb..#Event') is not null drop table #Event
Create table #Event (PersonID int, Description varchar(max),dt# int )

DECLARE @counter  INT;
DECLARE @counter1 INT;
SET @counter = (Select min(startDt#) from #Membership) ;
SET @counter1= (Select min(Row#1) from #Membership);

while @counter1 < (Select max (Row#1)+1 from #Membership)

begin

	while @counter < (Select endDt# +1 from #Membership where Row#1=@counter1)

	begin 

	insert into #Event
		Select PersonID, Description, @counter as dt# 
		from #Membership
		where Row#1=@counter1

		set @counter=@counter+1
	end
	set @counter1=@counter1+1
	set @counter= (Select startDt# from #Membership where Row#1= @counter1)
end

--select * from #Event
----------------------
----------------------
---Join event table and test 1 table
if OBJECT_ID('tempdb..#Test2') is not null drop table #Test2
Select distinct a.*, 
rank () over (order by a.startDate) as num, --ID for date
b.Description 
into #Test2

from #test1 a left join #Event b on a.personID=b.personID 

where dt#  between a.startDt# and a.endDt#
-- select * from #Test2
----------------------
----------------------
---- Final Result, merge the description

	Select personid, startdate,enddate,
	 stuff((select '-'+ Description 
	 From #Test2 b 
	 where a.num=b.num
	 order by 
	 case 
			when Description = 'Poker Club' then 1
			when Description = 'Library' then 2
			when Description = 'Gym' then 3
			when Description = 'Pilates' then 1
	end asc
	 for XML Path('')),1,1,'') as Description

	from #Test2 a
	group by PersonID,startDate,enddate, num

 