-- Этап 1. Создание и заполнение БД

/* Создание и наполнение схемы raw_data. */


CREATE SCHEMA raw_data; 


CREATE TABLE raw_data.sales (
	id INTEGER PRIMARY KEY,
	auto TEXT,
	gasoline_consumption NUMERIC,
	price NUMERIC,
	date DATE,
	person_name TEXT,
	phone TEXT,
	discount INTEGER,
	brand_origin TEXT
);


\copy raw_data.sales from '/Users/cars.csv' with csv header null 'null';


SELECT * 
FROM raw_data.sales;


CREATE SCHEMA car_shop;


/* Создание и наполнение схемы car_shop. */


CREATE TABLE car_shop.countries (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	country_name TEXT NOT NULL UNIQUE						-- в названии буквы, поэтому TEXT
);


INSERT INTO car_shop.countries (country_name)
SELECT DISTINCT 
	brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;


CREATE TABLE car_shop.colors (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	color TEXT NOT NULL UNIQUE  							-- в названии буквы, поэтому TEXT
);


INSERT INTO car_shop.colors (color)
SELECT DISTINCT 
	trim(split_part(auto, ',', 2)) AS color
FROM raw_data.sales;


CREATE TABLE car_shop.brands (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	brand_name TEXT NOT NULL,                             	-- в названии могут быть и цифры, и буквы, поэтому TEXT
	brand_origin_id  INTEGER REFERENCES car_shop.countries  -- внешний ключ, поэтому INTEGER
);


INSERT INTO car_shop.brands (brand_name, brand_origin_id)
SELECT DISTINCT 
	trim(split_part(split_part(s.auto, ',', 1), ' ', 1)) AS brand_name, 
	c.id AS brand_origin_id
FROM raw_data.sales s
LEFT JOIN car_shop.countries c ON c.country_name = s.brand_origin;


CREATE TABLE car_shop.cars (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	brand_id INTEGER REFERENCES car_shop.brands,			-- внешний ключ, поэтому INTEGER
	model TEXT NOT NULL UNIQUE,								-- в названии могут быть и цифры, и буквы, поэтому TEXT
	gasoline_consumption NUMERIC(3, 1) 			-- потребление бензина может содержать только десятые и не может быть больше трехзначной суммы. У numeric повышенная точность при работе с дробными числами. 
);


INSERT INTO car_shop.cars (brand_id, model, gasoline_consumption)
SELECT DISTINCT 
	b.id AS brand_id, 
	trim(substr(split_part(s.auto, ',', 1), strpos(split_part(s.auto, ',', 1), ' '))) AS model, 
	gasoline_consumption
FROM raw_data.sales s
LEFT JOIN car_shop.brands b ON b.brand_name = trim(split_part(split_part(s.auto, ',', 1), ' ', 1));


CREATE TABLE car_shop.car_color (
	car_id INTEGER REFERENCES car_shop.cars,				-- внешний ключ, поэтому INTEGER
	color_id INTEGER REFERENCES car_shop.colors				-- внешний ключ, поэтому INTEGER
);


INSERT INTO car_shop.car_color (car_id, color_id)
SELECT DISTINCT 
	cr.id AS car_id, 
	cl.id AS color_id
FROM raw_data.sales s
JOIN car_shop.cars cr ON cr.model = trim(substr(split_part(s.auto, ',', 1), strpos(split_part(s.auto, ',', 1), ' ')))
JOIN car_shop.colors cl ON cl.color = trim(split_part(s.auto, ',', 2));


CREATE TABLE car_shop.clients (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	first_name TEXT NOT NULL,								-- имя клиента содержит буквы, поэтому TEXT
	last_name TEXT NOT NULL,								-- фамилия клиента содержит буквы, поэтому TEXT
	phone_num TEXT UNIQUE									-- номер телефона содержит цифры и форматирующие знаки, поэтому TEXT
);


INSERT INTO car_shop.clients (first_name, last_name, phone_num)
SELECT DISTINCT 
	split_part(regexp_replace(
		person_name, '^(Mrs\.|Mr\.|Ms\.|Dr\.)?\s*([^ ]+)\s+([^ ]+)(\s+(Jr\.|MD|DVM|DDS|Sr\.|II|III|IV)?)?$', '\2 \3'),
			' ', 1) AS first_name,
	split_part(regexp_replace(
		person_name, '^(Mrs\.|Mr\.|Ms\.|Dr\.)?\s*([^ ]+)\s+([^ ]+)(\s+(Jr\.|MD|DVM|DDS|Sr\.|II|III|IV)?)?$', '\2 \3'),
			' ', 2) AS last_name,
	phone
FROM raw_data.sales;


CREATE TABLE car_shop.purchases (
	id SERIAL PRIMARY KEY,									-- первичный ключ
	car_id INTEGER REFERENCES car_shop.cars, 				-- внешний ключ, поэтому INTEGER
	price NUMERIC(9, 2) NOT NULL,							-- цена может содержать только сотые и не может быть больше семизначной суммы. У numeric повышенная точность при работе с дробными числами.
	date DATE NOT NULL,										-- дата покупки в исходном файле без указания веремени, поэтому DATE 
	discount INTEGER  DEFAULT 0,  							-- скидка представляет целое число и может превышать диапазон SMALLINT, поэтому INTEGER
	client_id INTEGER REFERENCES car_shop.clients			-- внешний ключ, поэтому INTEGER
);


INSERT INTO car_shop.purchases (car_id, price, date, discount, client_id)
SELECT DISTINCT 
	cr.id AS car_id, 
	round(s.price, 2) AS price, 
	s.date, 
	s.discount, 
	cl.id AS client_id
FROM raw_data.sales s
JOIN car_shop.cars cr ON cr.model = trim(substr(split_part(s.auto, ',', 1), strpos(split_part(s.auto, ',', 1), ' ')))
JOIN car_shop.clients cl ON cl.phone_num = s.phone;






-- Этап 2. Создание выборок

/* Задание 1 из 6

Напишите запрос, который выведет процент моделей машин, 
у которых нет параметра gasoline_consumption. */


SELECT 
	100 - (count(gasoline_consumption) * 100 / count(model)) AS nulls_percentage_gasoline_consumption
FROM car_shop.cars;


/* Задание 2 из 6

Напишите запрос, который покажет название бренда и среднюю цену его автомобилей 
в разбивке по всем годам с учётом скидки. 
Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой. */


SELECT 
	b.brand_name, 
	EXTRACT (YEAR FROM p.date) AS year,
	ROUND(AVG(p.price), 2) AS price_avg
FROM car_shop.brands b
JOIN car_shop.cars c ON c.brand_id = b.id
JOIN car_shop.purchases p ON p.car_id = c.id
GROUP BY b.brand_name, EXTRACT (YEAR FROM p.date)
ORDER BY b.brand_name, year;


/* Задание 3 из 6

Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
Результат отсортируйте по месяцам в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой. */


SELECT 
	EXTRACT (MONTH FROM DATE) AS month,
	EXTRACT (YEAR FROM date) AS year,
	ROUND(AVG(price), 2) AS price_avg
FROM car_shop.purchases 
WHERE EXTRACT (YEAR FROM date)  = '2022'
GROUP BY EXTRACT (MONTH FROM DATE), EXTRACT (YEAR FROM date)
ORDER BY month;


/* Задание 4 из 6

Используя функцию STRING_AGG, напишите запрос, который выведет список 
купленных машин у каждого пользователя через запятую. 
Пользователь может купить две одинаковые машины — это нормально. 
Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
Отсортируйте по имени пользователя в восходящем порядке. 
Сортировка внутри самой строки с машинами не нужна. */


SELECT 
	cl.first_name || ' ' || cl.last_name AS person,
	string_agg(b.brand_name || ' ' || c.model, ', ') AS cars
FROM car_shop.clients cl
JOIN car_shop.purchases p ON p.client_id = cl.id
JOIN car_shop.cars c ON c.id = p.car_id
JOIN car_shop.brands b ON b.id = c.brand_id
GROUP BY cl.first_name || ' ' || cl.last_name
ORDER BY person;

	
/* Задание 5 из 6

Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля 
с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки. */


SELECT 
	c.country_name AS brand_origin,
	MAX(p.price * (1 + p.discount)) AS price_max,
	MIN(p.price * (1 + p.discount)) AS price_min
FROM car_shop.countries c 
JOIN car_shop.brands b ON b.brand_origin_id = c.id
JOIN car_shop.cars cr ON cr.brand_id = b.id
JOIN car_shop.purchases p ON p.car_id = cr.id
GROUP BY c.country_name;


/* Задание 6 из 6

Напишите запрос, который покажет количество всех пользователей из США. 
Это пользователи, у которых номер телефона начинается на +1. */


SELECT COUNT(id) AS persons_from_usa_count
FROM car_shop.clients
WHERE phone_num LIKE '+1%';




