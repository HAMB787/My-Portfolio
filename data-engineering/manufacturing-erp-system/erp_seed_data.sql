USE manufacturing_erp;

-- ==========================================
-- 1. ԱՎԵԼԱՑՆՈՒՄ ԵՆՔ ՀՈՒՄՔ (Ինչ ունենք պահեստում)
-- ==========================================
INSERT INTO raw_materials (material_name, stock_quantity) VALUES 
('Փայտե վահանակ MDF (հատ)', 150),
('Մետաղական ոտք (հատ)', 500),
('Պտուտակ (հատ)', 10000),
('Կահույքի կտոր (մետր)', 300),
('Սպունգ (հատ)', 200);

-- ==========================================
-- 2. ԱՎԵԼԱՑՆՈՒՄ ԵՆՔ ԱՐՏԱԴՐԱՆՔ (Ինչ ենք վաճառում)
-- Նախնական քանակը դնում ենք 5, որպեսզի կարողանանք վաճառք թեստավորել
-- ==========================================
INSERT INTO products (product_name, stock_quantity, price) VALUES 
('Գրասենյակային սեղան', 5, 45000.00),
('Փափուկ բազկաթոռ', 5, 85000.00);

-- ==========================================
-- 3. ՍՏԵՂԾՈՒՄ ԵՆՔ ԲԱՂԱԴՐԱՏՈՄՍԸ (BOM) - ԱՄԵՆԱԿԱՐԵՎՈՐԸ
-- ==========================================

-- Գրասենյակային սեղանի (Product ID = 1) բաղադրատոմսը.
-- Պետք է 1 հատ MDF, 4 հատ ոտք, 24 հատ պտուտակ
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed) VALUES 
(1, 1, 1),   -- 1 Սեղանին -> 1 հատ MDF (Material ID 1)
(1, 2, 4),   -- 1 Սեղանին -> 4 հատ ոտք (Material ID 2)
(1, 3, 24);  -- 1 Սեղանին -> 24 հատ պտուտակ (Material ID 3)

-- Փափուկ բազկաթոռի (Product ID = 2) բաղադրատոմսը.
-- Պետք է 4 ոտք, 16 պտուտակ, 3 մետր կտոր, 2 սպունգ
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed) VALUES 
(2, 2, 4),   -- 1 Բազկաթոռին -> 4 հատ ոտք
(2, 3, 16),  -- 1 Բազկաթոռին -> 16 հատ պտուտակ
(2, 4, 3),   -- 1 Բազկաթոռին -> 3 մետր կտոր
(2, 5, 2);   -- 1 Բազկաթոռին -> 2 հատ սպունգ

-- ==========================================
-- 4. ԱՎԵԼԱՑՆՈՒՄ ԵՆՔ ԱՇԽԱՏԱԿԻՑՆԵՐ ԵՎ ՀԱՃԱԽՈՐԴՆԵՐ
-- ==========================================
INSERT INTO employees (first_name, last_name, position, hire_date) VALUES 
('Արամ', 'Արամյան', 'Վաճառքի մենեջեր', '2025-02-15'),
('Լիլիթ', 'Հովհաննիսյան', 'Արտադրամասի ղեկավար', '2024-11-01');

INSERT INTO customers (company_name, contact_name, email, phone) VALUES 
('ՏեխնոԱլյանս ՍՊԸ', 'Տիգրան Վարդանյան', 'tigran@techalliance.am', '091-11-22-33'),
('ՀԱՊՀ (Պոլիտեխնիկ)', 'Գնումների բաժին', 'procurement@polytech.am', '010-50-40-30');





USE manufacturing_erp;

DELIMITER //

CREATE TRIGGER trg_after_order_detail_insert
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    DECLARE current_stock INT;

    -- 1. Վերցնում ենք ապրանքի ներկայիս քանակը պահեստում
    SELECT stock_quantity INTO current_stock 
    FROM products 
    WHERE product_id = NEW.product_id;

    -- 2. Ստուգում ենք՝ արդյոք բավարար քանակ կա վաճառելու համար
    IF current_stock < NEW.quantity THEN
        -- Եթե չկա, արգելափակում ենք վաճառքը և ցույց ենք տալիս սխալ
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Սխալ: Պահեստում բավարար քանակ չկա տվյալ ապրանքից:';
    ELSE
        -- 3. Եթե բավարար է, նվազեցնում ենք պահեստի մնացորդը
        UPDATE products
        SET stock_quantity = stock_quantity - NEW.quantity
        WHERE product_id = NEW.product_id;
    END IF;
END //

DELIMITER ;





-- Նախքան վաճառքը եկեք ստուգենք, թե քանի սեղան ունենք (պետք է լինի 5 հատ)
SELECT product_name, stock_quantity FROM products WHERE product_id = 1;

-- 1. Բացում ենք նոր պատվեր ՀԱՊՀ-ի համար
INSERT INTO orders (customer_id, employee_id, status) 
VALUES (2, 1, 'Completed');

-- 2. Պատվերի մեջ ավելացնում ենք 2 հատ սեղան: 
-- ՈՒՇԱԴՐՈՒԹՅՈՒՆ. Հենց այս տողն աշխատացնես, քո գրած Տրիգերը կարթնանա!
INSERT INTO order_details (order_id, product_id, quantity, unit_price) 
VALUES (1, 1, 2, 45000.00);

-- Վաճառքից հետո նորից ստուգում ենք պահեստը (հիմա պետք է լինի 3 հատ)
SELECT product_name, stock_quantity FROM products WHERE product_id = 1;








DELIMITER //

CREATE PROCEDURE manufacture_product(IN p_product_id INT, IN p_quantity INT)
BEGIN
    DECLARE shortage_count INT;

    -- Սկսում ենք անվտանգ գործարքը (Transaction)
    START TRANSACTION;

    -- 1. ԽԵԼԱՑԻ ՍՏՈՒԳՈՒՄ. Նայում ենք, արդյոք որևէ հումք պակասում է
    SELECT COUNT(*) INTO shortage_count
    FROM raw_materials rm
    JOIN bill_of_materials bom ON rm.material_id = bom.material_id
    WHERE bom.product_id = p_product_id 
      AND rm.stock_quantity < (bom.quantity_needed * p_quantity);

    IF shortage_count > 0 THEN
        -- 2. Եթե հումքը չի հերիքում, չեղարկում ենք գործողությունը և տալիս սխալ
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Սխալ: Պահեստում չկա բավարար հումք պահանջված քանակն արտադրելու համար:';
    ELSE
        -- 3. ՆՎԱԶԵՑՆՈՒՄ ԵՆՔ ՀՈՒՄՔԸ (ըստ բաղադրատոմսի մաթեմատիկայի)
        UPDATE raw_materials rm
        JOIN bill_of_materials bom ON rm.material_id = bom.material_id
        SET rm.stock_quantity = rm.stock_quantity - (bom.quantity_needed * p_quantity)
        WHERE bom.product_id = p_product_id;

        -- 4. ԱՎԵԼԱՑՆՈՒՄ ԵՆՔ ՊԱՏՐԱՍՏԻ ԱՐՏԱԴՐԱՆՔԸ
        UPDATE products
        SET stock_quantity = stock_quantity + p_quantity
        WHERE product_id = p_product_id;

        -- 5. Հաստատում ենք փոփոխությունները
        COMMIT;
    END IF;
END //

DELIMITER ;



-- Կանչում ենք ծրագիրը (Արտադրել Ապրանք #1-ից 5 հատ)
CALL manufacture_product(1, 5);

-- Ստուգում ենք, թե ինչպես են ավելացել սեղանները
SELECT product_name, stock_quantity FROM products WHERE product_id = 1;

-- Ստուգում ենք, թե ինչպես է պակասել հումքը
SELECT material_name, stock_quantity FROM raw_materials;


















USE manufacturing_erp;

-- ==========================================
-- 1. ՆՈՐ ՀՈՒՄՔԵՐ (Raw Materials)
-- ==========================================
INSERT INTO raw_materials (material_name, stock_quantity) VALUES
('Ապակի (1մ x 1մ)', 50),
('Սպունգ (Պրեմիում)', 100),
('Կաշի (Սև)', 80),
('Մետաղական Կարկաս', 120),
('Փայտե պանել (Մեծ)', 200),
('Դարակի Սլայդ', 300);

-- ==========================================
-- 2. ՆՈՐ ԿԱՀՈՒՅՔ (Products)
-- ==========================================
INSERT INTO products (product_name, stock_quantity, price) VALUES
('Ապակյա Ժուռնալի Սեղան', 5, 65000),
('Կաշվե Բազմոց', 2, 350000),
('Գրապահարան (4-դարականի)', 8, 85000),
('Զգեստապահարան (Մեծ)', 4, 180000);

-- ==========================================
-- 3. ՄԵՐ ՀԱՃԱԽՈՐԴՆԵՐԸ (B2B և B2C)
-- ==========================================
INSERT INTO customers (company_name, contact_name, email, phone) VALUES
('ՀԱՊՀ (NPUA)', 'Ռեկտորատ / Գնումներ', 'info@polytech.am', '010-580000'),
('SoftConstruct', 'Օֆիս Մենեջեր', 'procurement@softconstruct.am', '011-123456'),
('Yerevan Hotel', 'Աննա Սարգսյան', 'anna@yerevanhotel.am', '099-001122');

-- ==========================================
-- 4. ԱՆՁՆԱԿԱԶՄ ԵՎ ՂԵԿԱՎԱՐՈՒԹՅՈՒՆ (Employees)
-- ==========================================
INSERT INTO employees (first_name, last_name, position) VALUES
('Համբարձում', '', 'Գլխավոր Ինժեներ / Data Architect'),
('Սուսաննա', '', 'Վաճառքի Տնօրեն (Sales Director)'),
('Արմեն', 'Պետրոսյան', 'Ավագ Պահեստապետ');

-- ==========================================
-- 5. ԽԵԼԱՑԻ ԲԱՂԱԴՐԱՏՈՄՍԵՐ (BOM) ՆՈՐ ԱՊՐԱՆՔՆԵՐԻ ՀԱՄԱՐ
-- (Օգտագործում ենք Subquery, որպեսզի ID-ները ավտոմատ ճիշտ կապվեն)
-- ==========================================

-- Ապակյա սեղան = 1 Ապակի + 1 Մետաղական կարկաս
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Ապակյա Ժուռնալի Սեղան' AND r.material_name = 'Ապակի (1մ x 1մ)';

INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Ապակյա Ժուռնալի Սեղան' AND r.material_name = 'Մետաղական Կարկաս';

-- Կաշվե բազմոց = 2 Կաշի + 3 Սպունգ + 2 Փայտե պանել
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Կաշվե Բազմոց' AND r.material_name = 'Կաշի (Սև)';

INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 3 FROM products p, raw_materials r WHERE p.product_name = 'Կաշվե Բազմոց' AND r.material_name = 'Սպունգ (Պրեմիում)';

INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Կաշվե Բազմոց' AND r.material_name = 'Փայտե պանել (Մեծ)';






USE manufacturing_erp;

-- ==========================================
-- 1. ՆՈՐ ՀՈՒՄՔԵՐ (Բազային դետալներ և փայտ)
-- ==========================================
INSERT INTO raw_materials (material_name, stock_quantity) VALUES
('Կաղնու Փայտ (Պրեմիում, 1մ³)', 40),
('Սոճու Փայտ (Ստանդարտ, 1մ³)', 100),
('Պտուտակների հավաքածու (1000 հատ)', 50),
('Փայտի Սոսինձ (Արդյունաբերական, 1լ)', 30),
('Լաք / Ներկ (Անգույն, 1լ)', 45),
('Կահույքի Գործվածք (1 գլանափաթեթ)', 20);

-- ==========================================
-- 2. ՆՈՐ ՊԱՏՐԱՍՏԻ ԱՐՏԱԴՐԱՆՔ
-- ==========================================
INSERT INTO products (product_name, stock_quantity, price) VALUES
('Մեծ Ճաշասեղան (Կաղնու փայտից)', 3, 150000),
('Փայտե Աթոռ (Դասական)', 15, 25000),
('Հեռուստացույցի Տակդիր (TV Stand)', 6, 55000),
('Ննջասենյակի Մահճակալ (Երկտեղանի)', 2, 220000);

-- ==========================================
-- 3. ՆՈՐ ՀԱՃԱԽՈՐԴՆԵՐ (B2B և Խանութներ)
-- ==========================================
INSERT INTO customers (company_name, contact_name, email, phone) VALUES
('Vega Electronics', 'Գնումների Բաժին', 'purchasing@vega.am', '010-445566'),
('Galaxy Group', 'Արամ Սաֆարյան', 'a.safaryan@galaxy.am', '011-998877'),
('ԱՁ Կարեն Մարտիրոսյան', 'Կարեն', 'karen.m@gmail.com', '094-112233');

-- ==========================================
-- 4. ՆՈՐ ԱՇԽԱՏԱԿԻՑՆԵՐ (Արտադրամաս)
-- ==========================================
INSERT INTO employees (first_name, last_name, position) VALUES
('Գոռ', 'Վարդանյան', 'Արտադրամասի Ղեկավար'),
('Լիլիթ', 'Մարտիրոսյան', 'Որակի Վերահսկիչ (QA)'),
('Դավիթ', 'Հակոբյան', 'Լոգիստիկայի Մասնագետ');

-- ==========================================
-- 5. ԲԱՐԴ ԲԱՂԱԴՐԱՏՈՄՍԵՐ (BOM) ՆՈՐ ԱՊՐԱՆՔՆԵՐԻ ՀԱՄԱՐ
-- ==========================================

-- Ճաշասեղան = 2 Կաղնի + 2 Լաք + 1 Սոսինձ + 1 Պտուտակների հավաքածու
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Մեծ Ճաշասեղան (Կաղնու փայտից)' AND r.material_name = 'Կաղնու Փայտ (Պրեմիում, 1մ³)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Մեծ Ճաշասեղան (Կաղնու փայտից)' AND r.material_name = 'Լաք / Ներկ (Անգույն, 1լ)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Մեծ Ճաշասեղան (Կաղնու փայտից)' AND r.material_name = 'Փայտի Սոսինձ (Արդյունաբերական, 1լ)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Մեծ Ճաշասեղան (Կաղնու փայտից)' AND r.material_name = 'Պտուտակների հավաքածու (1000 հատ)';

-- Դասական Աթոռ = 1 Սոճի + 1 Գործվածք + 1 Սպունգ + 1 Լաք
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Փայտե Աթոռ (Դասական)' AND r.material_name = 'Սոճու Փայտ (Ստանդարտ, 1մ³)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Փայտե Աթոռ (Դասական)' AND r.material_name = 'Կահույքի Գործվածք (1 գլանափաթեթ)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Փայտե Աթոռ (Դասական)' AND r.material_name = 'Սպունգ (Պրեմիում)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 1 FROM products p, raw_materials r WHERE p.product_name = 'Փայտե Աթոռ (Դասական)' AND r.material_name = 'Լաք / Ներկ (Անգույն, 1լ)';

-- Մահճակալ = 4 Կաղնի + 2 Մետաղական Կարկաս + 2 Պտուտակ
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 4 FROM products p, raw_materials r WHERE p.product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)' AND r.material_name = 'Կաղնու Փայտ (Պրեմիում, 1մ³)';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)' AND r.material_name = 'Մետաղական Կարկաս';
INSERT INTO bill_of_materials (product_id, material_id, quantity_needed)
SELECT p.product_id, r.material_id, 2 FROM products p, raw_materials r WHERE p.product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)' AND r.material_name = 'Պտուտակների հավաքածու (1000 հատ)';










USE manufacturing_erp;

-- ==========================================
-- Անվտանգ Վաճառքներ (Խուսափում ենք Error 1442-ից)
-- ==========================================

-- 1. ՀԱՊՀ-ի գնումները (Order 1)
SET @id1 = (SELECT product_id FROM products WHERE product_name = 'Ապակյա Ժուռնալի Սեղան');
SET @pr1 = (SELECT price FROM products WHERE product_name = 'Ապակյա Ժուռնալի Սեղան');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (1, @id1, 2, @pr1);

SET @id2 = (SELECT product_id FROM products WHERE product_name = 'Փայտե Աթոռ (Դասական)');
SET @pr2 = (SELECT price FROM products WHERE product_name = 'Փայտե Աթոռ (Դասական)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (1, @id2, 10, @pr2);

-- 2. SoftConstruct-ի գնումը (Order 2)
SET @id3 = (SELECT product_id FROM products WHERE product_name = 'Կաշվե Բազմոց');
SET @pr3 = (SELECT price FROM products WHERE product_name = 'Կաշվե Բազմոց');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (2, @id3, 1, @pr3);

-- 3. Yerevan Hotel-ի գնումները (Order 3)
SET @id4 = (SELECT product_id FROM products WHERE product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)');
SET @pr4 = (SELECT price FROM products WHERE product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (3, @id4, 2, @pr4);

SET @id5 = (SELECT product_id FROM products WHERE product_name = 'Հեռուստացույցի Տակդիր (TV Stand)');
SET @pr5 = (SELECT price FROM products WHERE product_name = 'Հեռուստացույցի Տակդիր (TV Stand)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (3, @id5, 2, @pr5);












USE manufacturing_erp;

-- ==========================================
-- ՊԱՏՎԵՐ 1. ՀԱՊՀ-ի գնումները
-- ==========================================
INSERT INTO orders (customer_id, employee_id, status) VALUES (1, 2, 'Completed');
SET @ord1 = LAST_INSERT_ID(); -- Ավտոմատ վերցնում ենք նոր պատվերի իրական ID-ն

SET @id1 = (SELECT product_id FROM products WHERE product_name = 'Ապակյա Ժուռնալի Սեղան');
SET @pr1 = (SELECT price FROM products WHERE product_name = 'Ապակյա Ժուռնալի Սեղան');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (@ord1, @id1, 2, @pr1);

SET @id2 = (SELECT product_id FROM products WHERE product_name = 'Փայտե Աթոռ (Դասական)');
SET @pr2 = (SELECT price FROM products WHERE product_name = 'Փայտե Աթոռ (Դասական)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (@ord1, @id2, 10, @pr2);

-- ==========================================
-- ՊԱՏՎԵՐ 2. SoftConstruct-ի գնումը
-- ==========================================
INSERT INTO orders (customer_id, employee_id, status) VALUES (2, 2, 'Completed');
SET @ord2 = LAST_INSERT_ID();

SET @id3 = (SELECT product_id FROM products WHERE product_name = 'Կաշվե Բազմոց');
SET @pr3 = (SELECT price FROM products WHERE product_name = 'Կաշվե Բազմոց');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (@ord2, @id3, 1, @pr3);

-- ==========================================
-- ՊԱՏՎԵՐ 3. Yerevan Hotel-ի գնումները
-- ==========================================
INSERT INTO orders (customer_id, employee_id, status) VALUES (3, 1, 'Completed');
SET @ord3 = LAST_INSERT_ID();

SET @id4 = (SELECT product_id FROM products WHERE product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)');
SET @pr4 = (SELECT price FROM products WHERE product_name = 'Ննջասենյակի Մահճակալ (Երկտեղանի)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (@ord3, @id4, 2, @pr4);

SET @id5 = (SELECT product_id FROM products WHERE product_name = 'Հեռուստացույցի Տակդիր (TV Stand)');
SET @pr5 = (SELECT price FROM products WHERE product_name = 'Հեռուստացույցի Տակդիր (TV Stand)');
INSERT INTO order_details (order_id, product_id, quantity, unit_price) VALUES (@ord3, @id5, 2, @pr5);


UPDATE products SET stock_quantity = 50;



update products   
SET product_name =  'Ապակյա փոքր Սեղան'
WHERE product_id = 3 ;


Select * 
FROM products;
