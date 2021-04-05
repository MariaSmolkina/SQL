-- Скрипты характерных выборок (включающие группировки, JOIN'ы, вложенные таблицы);

/* Скрипт 1
Запрос для подсчета количества доставок, которые были совершены с 2010 года.
*/

select
count(id) as amount
from orders_delivery
where year(delivered_at) >= '2010';

/* Скрипт 2
Запрос на получение данных о товарах (id и наименование), которых осталось мало на складе (не более 5 шт).
*/

select id, 
		(select name from products where id = storehouses_products.id) as product_name, 
		value
from storehouses_products
where value <= 5
order by id;

/* Скрипт 3
Запрос, чтобы выяснить, кто больше заказов совершил (всего): мужчины или женщины.
*/

select distinct p.gender,
count(po.profiles_id) as amount
from profiles p
left join 
profiles_orders po 
on p.id = po.profiles_id 
group by gender;

/* Скрипт 4
Запрос с целью подсчета количества заказов для каждого профиля.
*/
select 
p.id as profiles_id,
count(*) as amount
from 
	profiles as p
right join 
	profiles_orders as o
on p.id = o.profiles_id
group by profiles_id
order by amount desc;

/* Скрипт 5
Запрос на получение списка наименований товаров и каталогов из категории "18+".
*/
select 
p.name as product_name,
cat.name as catalog_name,
c.age_category as `age category`
from 
	products as p
right join 
	products_category as pc
on p.id = pc.products_id 
right join 
	catalogs as cat
on p.catalog_id = cat.id
right join 
	category as c 
on pc.age_category_id = c.id 
where c.age_category='18+'
order by product_name;

/* Скрипт 6
Запрос на определение числа профилей по городам, указанным в адресах профилей.
*/
select 
a.city as city,
count(*) as profiles_amount
from 
	profiles_addresses pa
right join 
	addresses a
on pa.addresses_id = a.id 
group by a.city 
order by profiles_amount desc;

-- Представления

/* Скрипт 7
Представление, содержащее название товарной позиции и соответствующее название каталога.
*/

create or replace view product_catalog(product_name, catalog_name) as 
select p.name, c.name 
from products p
left join 
catalogs c 
on p.catalog_id = c.id ;

select * from product_catalog
order by product_name;

/* Скрипт 8
Представление, содержащее название склада, наименование хранимой продукции и количество хранимых единиц.
*/
create or replace view storehouses_products_information(storehouse_name, product_name, product_total) as 
select s.name, p.name, sp.value 
from  storehouses s
left join 
addresses a 
on s.addresses_id = a.id
left join 
storehouses_products sp 
on s.id = sp.storehouse_id
left join 
products p 
on sp.product_id = p.id;

select * from storehouses_products_information
order by storehouse_name ;

/* Скрипт 9
Представление, содержащее список профилей, которые оформили заказ, а также номер их заказа и дату доставки.
*/

create or replace view profiles_orders_delivery(profile_id, order_id, delivery_date) as 
select p.id, o.id, od.delivery_date 
from profiles p
left join 
profiles_orders po 
on p.id = po.profiles_id 
left join 
orders o 
on po.orders_id = o.id 
left join
orders_delivery od 
on o.delivery_id = od.id 
where p.id = po.profiles_id ;

select * from profiles_orders_delivery
order by profile_id;

/* Скрипт 10
Представление, содержащее информацию об отзывах и оценках пользователей о товарах.
*/

create or replace view products_reviews_view(product_id, profile_id, raiting, review) as 
select pr.products_id, pr2.profiles_id, r.raiting,  r.description
from products_reviews pr
right join
reviews r 
on pr.reviews_id = r.id
right join profiles_reviews pr2 
on r.id = pr2.profiles_id ;

select * from products_reviews_view
order by product_id;

/* Скрипт 11
Представление, содержащее информацию о действующих акциях на товары.
*/

create or replace view active_promo(profile_id, product_id, discount, due_to) as 
select pc.user_id, ppc.products_id, pc.discount, pc.finished_at 
from promo_code pc 
right join products_promo_code ppc 
on pc.id = ppc.promo_code_id 
where pc.finished_at >= now();

select * from active_promo
order by profile_id;

-- Хранимые процедуры/триггеры

/* Скрипт 12 
Процедура, которая выводит сумму рассматриваего заказа.
*/

drop procedure if exists order_total_price;

DELIMITER //
create procedure order_total_price(order_id bigint)
begin 
	select sum(p.price*op.total) as total_order_price
from  orders_products op
left join 
products p
on op.product_id = p.id 
where op.order_id = order_id;
end;
delimiter ;

call order_total_price(17);

/* Скрипт 13
Процедура, которая выводит информацию о заказах искомого пользователя 
(id пользователя, id заказа, дата оформления заказа).
*/
drop procedure if exists profile_order;

DELIMITER //
create procedure profile_order(profile_id bigint)
begin
	select p.id, po.orders_id, o.created_at 
from  profiles p
left join 
profiles_orders po
on p.id = po.profiles_id 
left join 
orders o 
on po.orders_id = o.id 
where p.id = profile_id
order by p.id ;
end;
delimiter ;

call profile_order(11);

/* Скрипт 14 
Процедура, которая выводит название искомого склада и его полный адрес.
*/

drop procedure if exists storehouse_address;

DELIMITER //
create procedure storehouse_address(storehouse_id bigint)
begin
	select s.name, a.*
from  storehouses s
left join 
addresses a 
on s.addresses_id = a.id
where s.id = storehouse_id;
end;
delimiter ;

call storehouse_address(1);

/* Скрипт 15 
Процедура, которая выводит товары, которые соответствуют заданным
номеру каталога и возрастной категории.
*/

drop procedure if exists products_cat;

DELIMITER //
create procedure products_cat(catalog_id bigint, category_id varchar(45))
begin
	select p.name
from  products p
left join 
catalogs cat
on p.catalog_id = cat.id
left join 
products_category pc 
on p.id = pc.products_id 
left join 
category c 
on pc.age_category_id = c.id 
where c.age_category = category_id
order by p.name;
end;
delimiter ;

call products_cat(1, "12+");


/* Скрипт 16 
Триггер для случая, когда происходит попытка присвоить полям name с названием товара 
и description с его описанием в таблице products NULL-значение.
*/

drop trigger if exists name_null_control;
delimiter //
create trigger name_null_control 
before insert on products 
for each row 
begin 
	if(isnull(new.name)) then set new.name = 'Empty name';
	end if;
	if(isnull(new.description)) then set new.description = 'Empty description';
	end if;	
end //
delimiter ;

/* Скрипт 17
Процедура добавления новой записи о доставке в таблице orders_delivery.
*/

DROP PROCEDURE IF EXISTS `add_order`;

DELIMITER //

CREATE PROCEDURE `add_order`(delivery_date datetime, address_id bigint, delivered_at datetime, OUT tran_result varchar(200))
BEGIN
    DECLARE `_rollback` BOOL DEFAULT 0;
   	DECLARE code varchar(100);
   	DECLARE error_string varchar(100);

   DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   begin
    	SET `_rollback` = 1;
	GET stacked DIAGNOSTICS CONDITION 1
          code = RETURNED_SQLSTATE, error_string = MESSAGE_TEXT;
    	set tran_result := concat('Error occured. Code: ', code, '. Text: ', error_string);
    end;
		        
    START TRANSACTION;
  		INSERT INTO orders_delivery (id, delivery_date, address_id, delivered_at)
		  VALUES (last_insert_id(), delivery_date, address_id, delivered_at);
	
	    IF `_rollback` THEN
	       ROLLBACK;
	    ELSE
		set tran_result := 'added';
	       COMMIT;
	    END IF;
end//

DELIMITER ;

call add_order('2020-11-26 04:34:09', 5 , '2020-11-29 04:34:09', @tran_result);
select @tran_result;


