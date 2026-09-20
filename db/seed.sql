-- Carga inicial del menú actual (21 categorías, 174 productos).
-- Es seguro correrlo más de una vez: solo inserta si la tabla categories está vacía.

do $seed$
begin
  if exists (select 1 from public.categories) then
    raise notice 'Ya hay datos, no se carga el seed.';
    return;
  end if;

  -- entradas · Entradas
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Entradas', 'entradas', null, 'cards', 10) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Croquetas Artesanales', 'pechuga de pollo o jamón ibérico · salsa pomodoro', 450::numeric, 'img/menu/img001.jpeg', 10),
    ('Taquitos de Churrasco', 'pimientos · pico de gallo', 675::numeric, 'img/menu/img002.jpeg', 20),
    ('Camarones Tempura', 'salsa guilin chili · puerro', 650::numeric, 'img/menu/img003.jpeg', 30),
    ('Mofonguitos de Camarones', 'pimientos rojos · Ginas hierbas', 650::numeric, 'img/menu/img004.jpeg', 40),
    ('Carpaccio de Res', 'rúcula · queso parmesano · vinagreta de mostaza', 750::numeric, 'img/menu/img005.jpeg', 50),
    ('Berenjena a la parmesana', 'berenjena en salsa rosa', 450::numeric, 'img/menu/img026.jpeg', 60),
    ('Burrata con Prosciutto', 'mermelada · aceitunas · rúcula', 650::numeric, 'img/menu/img006.jpeg', 70),
    ('Canasticas de camarones', 'camarones a la crema', 500::numeric, null, 80),
    ('Canasticas de pechuga de pollo', 'pechuga de pollo a la crema', 400::numeric, 'img/menu/img024.jpeg', 90),
    ('Tuna Tartar', 'atún marinado · aguacate', 750::numeric, 'img/menu/img007.jpeg', 100),
    ('Aros de Calamar Crujiente', 'salsa tártara', 450::numeric, 'img/menu/img008.jpeg', 110)
  ) as v(name, description, price, image_url, sort);

  -- principales · Pastas y Arroces
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Pastas y Arroces', 'principales', null, 'cards', 20) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Penne en Salsa 4 Quesos de Pollo', 'pechuga de pollo en salsa cuatro quesos', 800::numeric, 'img/menu/img009.jpeg', 10),
    ('Penne en Salsa 4 Quesos de Camarones', 'camarones en salsa cuatro quesos', 900::numeric, 'img/menu/img010.jpeg', 20),
    ('Fettuccine a la Carbonara', 'pancetta frita crocante en salsa carbonara', 850::numeric, 'img/menu/img011.jpeg', 30),
    ('Fettuccine de Mariscos', 'camarones, calamares y almejas en salsa pomodoro', 950::numeric, 'img/menu/img012.jpeg', 40),
    ('Chowfan Bambú', 'res, pollo y camarones, vegetales y huevo pochado', 1000::numeric, 'img/menu/img013.jpeg', 50)
  ) as v(name, description, price, image_url, sort);

  -- principales · Extras Bambú
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Extras Bambú', 'principales', null, 'cards', 30) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Mofongo Volcán', 'salsa alfredo · camarones', 1300::numeric, 'img/menu/img014.jpeg', 10),
    ('Mofongo de Pollo', 'pechuga de pollo', 950::numeric, 'img/menu/img015.jpeg', 20),
    ('Mofongo de Costilla', 'costilla de cerdo', 1300::numeric, 'img/menu/img022.jpeg', 30),
    ('Mofongo de Chicharron', 'chicharrón de cerdo', 1200::numeric, 'img/menu/img023.jpeg', 40),
    ('Mofongo de pechuga a la crema', 'pechuga a la crema', 1000::numeric, 'img/menu/img027.jpeg', 50),
    ('Clásica Suprema Bambú', 'pan brioche · carne angus 8 oz · vegetales frescos · salsa el bambú', 750::numeric, 'img/menu/img016.jpeg', 60),
    ('Pechuga al maduro en salsa alfredo', 'pechuga de pollo en salsa alfredo con plátano maduro', 950::numeric, 'img/menu/img025.jpeg', 70),
    ('Pechuga a la Gordon Blue', 'pechuga de pollo rellena · salsa blanca', 950::numeric, 'img/menu/img017.jpeg', 80),
    ('Pechuga a la Plancha', 'pechuga de pollo al grill', 875::numeric, 'img/menu/img018.jpeg', 90),
    ('Pechurinita con papa', 'pechurinitas', 500::numeric, null, 100)
  ) as v(name, description, price, image_url, sort);

  -- principales · Guarniciones
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Guarniciones', 'principales', null, 'list', 40) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Papas Fritas', '', 150::numeric, null, 10),
    ('Tostones', '', 150::numeric, null, 20),
    ('Yuca Mash', '', 200::numeric, null, 30),
    ('Puré de Papa', '', 170::numeric, null, 40),
    ('Papas Salteadas', '', 180::numeric, null, 50),
    ('Vegetales al Grill', '', 170::numeric, null, 60)
  ) as v(name, description, price, image_url, sort);

  -- principales · Ensaladas
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Ensaladas', 'principales', null, 'cards', 50) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Ensalada de atún', '', 700::numeric, null, 10),
    ('Ensalada cesar', '', 700::numeric, null, 20),
    ('Ensalada el bambú', '', 850::numeric, null, 30)
  ) as v(name, description, price, image_url, sort);

  -- principales · Cortes Importados
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Cortes Importados', 'principales', null, 'cards', 60) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Churrasco Angus (10 oz)', '', 1600::numeric, 'img/menu/img028.jpeg', 10),
    ('Picaña (10 oz)', '', 1700::numeric, null, 20),
    ('Rib Eye (10 oz)', '', 2000::numeric, null, 30),
    ('Tomahawk', '', 4600::numeric, 'img/menu/img029.jpeg', 40),
    ('Costillas Baby Back', '', 1200::numeric, 'img/menu/img030.jpeg', 50),
    ('Filete migñon en salsa de champiñones trinchado', '', 1500::numeric, null, 60)
  ) as v(name, description, price, image_url, sort);

  -- principales · Mariscos
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Mariscos', 'principales', null, 'cards', 70) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Camarones al Ajillo', '', 850::numeric, null, 10),
    ('Camarones a la Crema', '', 880::numeric, null, 20),
    ('Salmón a la Plancha', '', 950::numeric, 'img/menu/img020.jpeg', 30),
    ('Salmón en Salsa Chimichurri', '', 950::numeric, 'img/menu/img021.jpeg', 40),
    ('Salmón a la Chinola', '', 980::numeric, 'img/menu/img019.jpeg', 50),
    ('Pulpo al Bambú', '', 1300::numeric, 'img/menu/img033.jpeg', 60),
    ('Salpicon de Mariscos', '', 800::numeric, null, 70),
    ('Cazuela de mariscos', '', 1350::numeric, null, 80),
    ('Filete de mero al limón', '', 700::numeric, null, 90),
    ('Filete de mero a la plancha', '', 680::numeric, null, 100),
    ('Langosta rellena de camarones', '', 2400::numeric, 'img/menu/img034.jpeg', 110),
    ('Langosta al estilo bambú', '', 1800::numeric, null, 120)
  ) as v(name, description, price, image_url, sort);

  -- principales · Platos de la Casa
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Platos de la Casa', 'principales', null, 'cards', 80) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Rabo encendido al estilo bambú', '', 700::numeric, null, 10)
  ) as v(name, description, price, image_url, sort);

  -- principales · Parrillada
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Parrillada', 'principales', null, 'cards', 90) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Parrillada al Bambú', 'churrasco · picaña · costillas baby back · pechuga de pollo · salchichas alemanas', 2300::numeric, 'img/menu/img031.jpeg', 10),
    ('Parrillada Mar y Tierra', 'churrasco · camarones · pollo · calamares', 2200::numeric, 'img/menu/img032.jpeg', 20)
  ) as v(name, description, price, image_url, sort);

  -- postres · Postres
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Postres', 'postres', null, 'cards', 100) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Brownie a la Moda', 'con helado artesanal', 435::numeric, null, 10),
    ('Delicias del Bambú', 'Cheesecake', 475::numeric, null, 20),
    ('Flan Imperial', 'flan de vainilla · dulce de leche', 400::numeric, null, 30)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Cócteles Clásicos · Cócteles Clásicos
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Cócteles Clásicos', 'bebidas', 'Cócteles Clásicos', 'cards', 110) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Margarita Clásica', 'Tequila, Licor de Naranja, Zumo de Limón, Miel de Agave, sal', 350::numeric, 'img/menu/img101.jpeg', 10),
    ('Margarita de Chinola', 'Tequila, Licor de Naranja, Zumo de Chinola, Miel de Agave, sal', 350::numeric, 'img/menu/img102.jpeg', 20),
    ('Mojito de Limón', 'Ron Blanco, Menta, Limón, Bitter, Azúcar, Soda', 350::numeric, 'img/menu/img103.jpeg', 30),
    ('Mojito de Chinola', 'Ron Blanco, Menta, Chinola, Limón, Azúcar, Soda', 350::numeric, 'img/menu/img104.jpeg', 40),
    ('Mojito de Coco', 'Ron Blanco, Menta, Crema de Coco, Limón, Soda, Coco Deshidratado', 380::numeric, 'img/menu/img105.jpeg', 50),
    ('Moscow Mule', 'Vodka, Limón, Miel opcional, Ginger Beer', 400::numeric, null, 60),
    ('Gin Tonic Clásico', 'Ginebra, Agua Tónica, Cortezas de Cítricos', 400::numeric, null, 70),
    ('Vodka Tónic', 'Vodka, agua tónica, limón', 300::numeric, null, 80),
    ('Daiquiri Limón', 'Ron Blanco, Limón, Azúcar', 250::numeric, null, 90),
    ('Expreso Martini', 'Vodka, Licor de Café, Café Expreso, Syrop Simple', 350::numeric, null, 100),
    ('Cosmopolitan', 'Vodka, Licor de Naranja, Limón, Arándano, Sirop', 300::numeric, null, 110),
    ('Caipirinha', 'Ron Blanco, Trozos de Limón, Azúcar Granulada', 350::numeric, null, 120),
    ('Piña Colada', 'Ron Blanco, Zumo de Piña, Crema de Coco, Leche Evaporada', 300::numeric, null, 130),
    ('Martini Dry', 'Ginebra, Vermut Dry', 300::numeric, null, 140),
    ('Sangría Tinta', 'Vino Tinto, Ron Blanco, Licor de Naranja, Frutas, Especia', 350::numeric, null, 150),
    ('Lychee Martini', 'Vodka, Lychee, Licor de Naranja, Limón', 430::numeric, null, 160),
    ('Sexy Berry', '', 400::numeric, null, 170),
    ('Manhattan', 'Whisky, Vermut Rosso, Bitter, Cereza', 350::numeric, null, 180),
    ('Negrony', 'Vermouth rojo, Campari, Ginebra', 350::numeric, 'img/menu/img106.jpeg', 190),
    ('Isla Dorada', 'Ron blanco, Syrope de piña, Zumo de limón, Zumo de chinola, Angostura, Top de sod', 350::numeric, 'img/menu/img114.jpeg', 200),
    ('Dulce Tentación', 'Ron blanco, Syrope de flor de jamaica, Crema de coco y Zumo de limon', 350::numeric, 'img/menu/img115.jpeg', 210),
    ('Pasión Encendida', 'Syrope rosado, Ron blanco, Ron oscuro, Vodka, Limón, Soda amarilla', 380::numeric, 'img/menu/img116.jpeg', 220),
    ('Bosque Nocturno', 'Syrope de uva, Vodka, Triple sec, Limón hojas de menta, Soda con gas', 350::numeric, 'img/menu/img118.jpeg', 230),
    ('Mar Caribe', 'Tequila, Triple sec, Syrope de piña, Crema de coco, Limón, Pizca de tajin', 350::numeric, 'img/menu/img117.jpeg', 240),
    ('Aperol', 'Prosseco, Aperol, Soda con gas', 350::numeric, 'img/menu/img113.jpeg', 250)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / De la Casa · De la Casa
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('De la Casa', 'bebidas', 'De la Casa', 'cards', 120) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('La Ex', 'Whisky, syrop especies, Bitter de naranja, Bitter de cacao', 400::numeric, 'img/menu/img107.jpeg', 10),
    ('La Popi', 'Tequila, vodka, syrop de flor de jamaica, sour de chinola, Espumante', 500::numeric, 'img/menu/img108.jpeg', 20),
    ('La Poderosa', '', 600::numeric, null, 30),
    ('El Bambú', 'Ron blanco, vodka, infusión de té verde, licor de melón sour, Menta', 500::numeric, 'img/menu/img109.jpeg', 40),
    ('La Diabla', 'Tequila, Ron añejo, Syrop de piña y canela, Naranja, Limón espumante', 400::numeric, 'img/menu/img110.jpeg', 50)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Mocktails · Mocktails
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Mocktails', 'bebidas', 'Mocktails', 'cards', 130) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Bambú Beer', 'Limón, Piña, Syrop de Menta, Cerveza SIN ALCOHOL', 250::numeric, null, 10),
    ('Amor Tropical', 'Fresas, Manzana sour, Manzanilla, Canela, Soda', 250::numeric, 'img/menu/img112.jpeg', 20),
    ('Rosé Bambú', 'Agua de rosa, Flor de Jamaica, Menta, Fresa', 250::numeric, null, 30),
    ('La viuda blanca', '', 750::numeric, null, 40),
    ('Chica Tropical', '', 450::numeric, null, 50),
    ('Cherry Bebé', 'Refresco de limón, Syrop de frambuesa cherry', 150::numeric, null, 60)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Tragos · Tragos
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Tragos', 'bebidas', 'Tragos', 'list', 140) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Buchanan Máster', '', 400::numeric, null, 10),
    ('Doble Reserva', '', 250::numeric, null, 20),
    ('Stolinaya', '', 300::numeric, null, 30),
    ('Trago de Aperol', '', 350::numeric, null, 40),
    ('Cuba Libre', '', 250::numeric, null, 50),
    ('Brugal Leyenda', '', 350::numeric, null, 60),
    ('Shot Don Julio', '', 450::numeric, null, 70),
    ('Shot de Patrón', '', 300::numeric, null, 80),
    ('Trago de Bailey', '', 300::numeric, null, 90),
    ('José el Cuervo Shot', '', 250::numeric, null, 100)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Cervezas · Cervezas
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Cervezas', 'bebidas', 'Cervezas', 'list', 150) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Cerveza Corona', '', 200::numeric, null, 10),
    ('Cerveza Presidente', '', 160::numeric, null, 20),
    ('Cerveza Presidente Dura', '', 160::numeric, null, 30),
    ('Cerveza Modelo', '', 200::numeric, null, 40),
    ('Cerveza a Smirnoff', '', 210::numeric, null, 50)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Vinos · Vinos
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Vinos', 'bebidas', 'Vinos', 'list', 160) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Luna Luna', '', 2500::numeric, null, 10),
    ('Casillero del Diablo', '', 2300::numeric, null, 20),
    ('19 Crímenes', '', 2400::numeric, null, 30),
    ('Frontera Cabernet Sauvignon', '', 2500::numeric, null, 40),
    ('Culito', '', 1600::numeric, null, 50),
    ('Vino 689', '', 2300::numeric, null, 60),
    ('Beringer Rosado', '', 1600::numeric, null, 70),
    ('Protos Reservas', '', 4500::numeric, null, 80),
    ('Protos Crianza 2019', '', 3300::numeric, null, 90),
    ('Merlot', '', 1600::numeric, null, 100),
    ('Glorioso', '', 2000::numeric, null, 110),
    ('Pedro', '', 2400::numeric, null, 120)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Espumante · Espumante
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Espumante', 'bebidas', 'Espumante', 'list', 170) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Chapanne Chandon Rosé', '', 8500::numeric, null, 10),
    ('Champagne Veuve Clicquot', '', 8000::numeric, null, 20),
    ('Freixinet', '', 1700::numeric, null, 30),
    ('Moet Ice', '', 7500::numeric, null, 40),
    ('Don Periñon', '', 27000::numeric, null, 50)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Botellas · Botellas
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Botellas', 'bebidas', 'Botellas', 'list', 180) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Gold Label', '', 5800::numeric, null, 10),
    ('Buchanans Máster', '', 4900::numeric, null, 20),
    ('Buchanans 12 Años', '', 3300::numeric, null, 30),
    ('Don Julio Reposado', '', 6800::numeric, null, 40),
    ('Casa Amigo', '', 5400::numeric, null, 50),
    ('Chivas Rigas 18 Años', '', 7900::numeric, null, 60),
    ('Chivas Rigas 12 Años', '', 2850::numeric, null, 70),
    ('Old Pac 12 Años', '', 3250::numeric, null, 80),
    ('Doble Reserva', '', 1600::numeric, null, 90),
    ('Extra Viejo', '', 1380::numeric, null, 100),
    ('Leyenda', '', 2000::numeric, null, 110),
    ('Fareball', '', 900::numeric, null, 120),
    ('Bombay', '', 2600::numeric, null, 130),
    ('Don Julio 1942', '', 14800::numeric, null, 140),
    ('Clase Azul', '', 17500::numeric, null, 150),
    ('Patrón Silver', '', 4900::numeric, null, 160),
    ('Blue Label', '', 21800::numeric, null, 170),
    ('Green Label', '', 6200::numeric, null, 180),
    ('Black Label', '', 3350::numeric, null, 190),
    ('Stolichnaya', '', 2000::numeric, null, 200),
    ('Titos', '', 2850::numeric, null, 210)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Jugos & Otros · Jugos Naturales
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Jugos Naturales', 'bebidas', 'Jugos & Otros', 'list', 190) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Jugo de Limón', '', 150::numeric, null, 10),
    ('Jugo de Cereza', '', 150::numeric, null, 20),
    ('Jugo de China', '', 150::numeric, null, 30),
    ('Jugo de Chinola', '', 150::numeric, null, 40)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Jugos & Otros · Soft Drinks
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Soft Drinks', 'bebidas', 'Jugos & Otros', 'list', 200) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Agua Natural', '', 50::numeric, null, 10),
    ('Agua San Pelegrino', '', 250::numeric, null, 20),
    ('Agua Tónica', '', 115::numeric, null, 30),
    ('Soda Amarga', '', 115::numeric, null, 40),
    ('Agua Perrier', '', 200::numeric, null, 50),
    ('Refrescos', '', 70::numeric, null, 60),
    ('Red Bull', '', 200::numeric, null, 70),
    ('Ciclón', '', 300::numeric, null, 80),
    ('Jugo Moet', '', 200::numeric, null, 90),
    ('Gramberry', '', 250::numeric, null, 100),
    ('Gatorade', '', 100::numeric, null, 110),
    ('Jugo de Naranja', '', 150::numeric, null, 120),
    ('Capuccino', '', 150::numeric, null, 130),
    ('Caffee Negro', '', 100::numeric, null, 140),
    ('Frappuccino', '', 300::numeric, null, 150),
    ('Café Frío', '', 200::numeric, null, 160),
    ('Cherry', '', 350::numeric, null, 170),
    ('Manís', '', 200::numeric, null, 180),
    ('Aceitunas', '', 250::numeric, null, 190)
  ) as v(name, description, price, image_url, sort);

  -- bebidas / Jugos & Otros · Digestivos
  with c as (
    insert into public.categories (name, screen, tab, layout, sort)
    values ('Digestivos', 'bebidas', 'Jugos & Otros', 'list', 210) returning id
  )
  insert into public.products (category_id, name, description, price, image_url, sort)
  select c.id, v.name, v.description, v.price, v.image_url, v.sort
  from c, (values
    ('Frangelico', '', 250::numeric, null, 10),
    ('Sambvca Romana', '', 270::numeric, null, 20),
    ('Amaro Aveno', '', 240::numeric, null, 30)
  ) as v(name, description, price, image_url, sort);

end
$seed$;
