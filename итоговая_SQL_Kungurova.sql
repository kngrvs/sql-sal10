-- 1. В каких городах больше одного аэропорта?

-- Подсчитываем количество аэропортов в каждом городе с помощью count 
-- группируем по названию города и выводим в результат только те города, в которых получившееся количество больше одного

select city as Город, count(airport_code) as Количество 
from airports 
group by city 
having count(airport_code) > 1 


-- 2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

-- создаем подзапрос, в котором находим самолет с максимальной дальностью перелета в таблице aircrafts
-- создаем еще один подзапрос, в котором связываем данние о модели с данными о максимальной дальности
-- для того, чтобы связать информацию об аэропортах и самолетах, объединяем таблицы airports и flights 
-- выводим название аэропортов, которые соответствуют условию

select distinct airport_name||', '||airport_code||', '||city as Аэропорт
from airports a 
join flights f on f.arrival_airport = a.airport_code or f.departure_airport = a.airport_code 
where f.aircraft_code = (
                         select aircraft_code
                         from aircrafts a              
                         where a."range" = (
                                            select max (a2."range") from aircrafts a2
                                            )
                         )

-- 3. Вывести 10 рейсов с максимальным временем задержки вылета
                         
-- выбираем ненулевые значение времени отправления по расписанию и фактического времени отправления, 
-- чтобы иметь возможность посчитать задержку вылета во времени
-- в вычисляемом столбце считаем разницу
-- упроядочиваем полученные данные по убыванию и выводим только первые 10 записей с помощью limit                        

select flight_no, 
       departure_airport, 
       arrival_airport, 
       actual_departure - scheduled_departure as "Задержка вылета" 
from flights f 
where f.actual_departure is not null and f.scheduled_departure is not null
order by 4 desc limit 10 


-- 4. Были ли брони, по которым не были получены посадочные талоны?

-- если в БД есть запись о брони, но этой записи не соответствует запись о посадочном талоне, в таком случае значение boarding_no будет null
-- нас интересует соответствие информации в таблицах bookings, tickets и boarding passes 
-- используем левое присоединение, чтобы в результат попадали совпадающие по ключу данные таблиц и все записи из левой таблицы, 
-- для которых не нашлось пары в правой 

select b.book_ref, b.book_date::date, bp.boarding_no 
from bookings b 
left join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.boarding_no is null


-- 5.Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
--Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом 
--или более ранних рейсах в течении дня.

-- в подзапросе к таблице seats находим общее количество мест для каждой модели самолета
-- в подзапросе к таблице boarding_passes считаем количество пассажиров, получивших посадочный талон на каждом рейсе
-- вычисляем количество пустых мест для каждого рейса
-- вычисляем процент свободных мест с помощью математической формулы и функции round
-- в столбце с накопительным итогом группируем фактических пассажиров по дате, накопление протсходит по каждому аэропорту за каждый день

select f.flight_no, 
       f.departure_airport, 
       f.arrival_airport, 
       ts.total_seats,
       ts.total_seats - fp.fact_passengers as empty_seats, 
       round ((ts.total_seats::numeric - fp.fact_passengers::numeric)*100 / ts.total_seats::numeric, 2) as percent, 
       sum (fp.fact_passengers) over (partition by f.actual_departure::date, f.departure_airport order by f.actual_departure) as cumulative
from flights f 
join (
      select f.flight_id, 
      count (bp.seat_no) as fact_passengers
      from boarding_passes bp
      join flights f on f.flight_id = bp.flight_id 
      group by f.flight_id
      ) as fp
on f.flight_id = fp.flight_id 
join (
      select s.aircraft_code, 
      count (s.seat_no) as total_seats 
from seats s
group by s.aircraft_code) as ts
on ts.aircraft_code = f.aircraft_code 


-- 6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.

-- в подзапросе объединяем данные таблиц aircrafts и flights
-- и вычисляем количество перелетов, своершаемое каждым типом самолета
-- группируем по названию модели
-- в результат выводим название модели и вычисляемый столбец с процентным соотношением перелетов по типам самолетов от общего количества

select model, (round(quantity / (sum(quantity) over ()), 2) * 100) as percent
from (
      select count(flight_id) as quantity, model
      from flights f 
      join aircrafts a on a.aircraft_code = f.aircraft_code
      group by model
      ) fa
group by fa.model, fa.quantity  


-- 7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

-- создаем отдельные cte для эконом класса и бизнес класса, в них будут находиться данные о ценах на перелет
-- в результат выводим те города, в которые цена на билет в бизнес класс дешевле, чем в эконом

with cte_economy as (select tf.flight_id, tf.ticket_no, tf.amount 
	                 from ticket_flights tf 
	                 where tf.fare_conditions = 'Economy'),
cte_business as (select tf.flight_id, tf.ticket_no, tf.amount 
	             from ticket_flights tf 
	             where tf.fare_conditions = 'Business')
select distinct a.city
from cte_economy 
join cte_business on cte_business.flight_id = cte_economy.flight_id 
and cte_economy.amount > cte_business.amount
join flights f on cte_economy.flight_id = f.flight_id 
join airports a on f.arrival_airport = a.airport_code

-- 8. Между какими городами нет прямых рейсов?

-- создаем представление cities_view со всеми возможными сочетаниями городов
-- в запросе объединяем таблицу airports с ней же, но с условием distinct,
-- чтобы убрать из результата те города, в которых больше одного аэропорта,
-- и с условием where, чтобы не было связки из одинаковых городов.
-- Используем except чтобы найти разность двух выборок, тем самым исключая прямые рейсы.

create view cities_view as
select fv.departure_city, fv.arrival_city
from flights_v fv

select distinct a.city, a1.city
from airports a
cross join airports a1
where a.city != a1.city
except
select cv.departure_city, cv.arrival_city
from cities_view cv
order by 1, 2


-- 9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, 
-- обслуживающих эти рейсы *
-- d = arccos {sin(latitude_a)·sin(latitude_b) + cos(latitude_a)·cos(latitude_b)·cos(longitude_a - longitude_b)}
-- L = d·R, где R = 6371 км

-- Так как нам нужны данные о прямых перелетах, добавляем данные из таблицы airports два раза,
-- используя левый джойн по коду аэропорта отправления и по коду аэропорта прибытия.
-- Такж нам нужны будут данные из таблиц flights и aircrafts.
-- В запросе указываем в том числе вычисляемые столбцы и столбец с условием case.

select distinct a2.city as "Город отправления", 
                a.city as "Город прибытия",
                round(acos((sind(a2.latitude)*sind(a.latitude)+cosd(a2.latitude)*cosd(a.latitude)*cosd(a2.longitude - a.longitude)))::numeric*6371, 2) as "Расстояние", 
                a3."range" as "Макс_дальность", 
                a3.model as "Модель", 
                a3."range" - round(acos((sind(a2.latitude)*sind(a.latitude)+cosd(a2.latitude)*cosd(a.latitude)*cosd(a2.longitude -a.longitude)))::numeric*6371, 0) as "Разница",
                case 
                when range > round(acos((sind(a2.latitude)*sind(a.latitude)+cosd(a2.latitude)*cosd(a.latitude)*cosd(a2.longitude - a.longitude)))::numeric*6371, 2)
                then 'ок'
                else 'not ok'
                end result
from flights f 
left join airports a on a.airport_code = f.arrival_airport
left join airports a2 on a2.airport_code = f.departure_airport
left join aircrafts a3 on a3.aircraft_code = f.aircraft_code 

































