-- 0003 Reference data: currencies and categories (planning/03-backend.md §2, 08-feature-specs.md #13).
-- Read-only for users (RLS + grants in 0005).

create table public.currencies (
  code char(3) primary key check (code ~ '^[A-Z]{3}$'),
  exponent smallint not null check (exponent between 0 and 4),
  name text not null check (char_length(name) between 1 and 80),
  symbol text not null check (char_length(symbol) between 1 and 8),
  frankfurter boolean not null default false
);

comment on table public.currencies is 'ISO 4217 currencies; exponent = minor-unit digits (money.exponent).';

-- ISO 4217 currencies served by Frankfurter v2 (research 05 §9). Exponent from the money engine rule.
insert into public.currencies (code, exponent, name, symbol, frankfurter)
select c.code, money.exponent(c.code), c.name, c.symbol, true
from (values
  ('AED', 'UAE Dirham', 'AED'), ('AFN', 'Afghan Afghani', '؋'), ('ALL', 'Albanian Lek', 'L'),
  ('AMD', 'Armenian Dram', '֏'), ('ANG', 'Netherlands Antillean Guilder', 'ƒ'), ('AOA', 'Angolan Kwanza', 'Kz'),
  ('ARS', 'Argentine Peso', '$'), ('AUD', 'Australian Dollar', 'A$'), ('AWG', 'Aruban Florin', 'ƒ'),
  ('AZN', 'Azerbaijani Manat', '₼'), ('BAM', 'Bosnia-Herzegovina Convertible Mark', 'KM'),
  ('BBD', 'Barbadian Dollar', '$'), ('BDT', 'Bangladeshi Taka', '৳'), ('BHD', 'Bahraini Dinar', 'BD'),
  ('BIF', 'Burundian Franc', 'FBu'), ('BMD', 'Bermudan Dollar', '$'), ('BND', 'Brunei Dollar', '$'),
  ('BOB', 'Bolivian Boliviano', 'Bs'), ('BRL', 'Brazilian Real', 'R$'), ('BSD', 'Bahamian Dollar', '$'),
  ('BTN', 'Bhutanese Ngultrum', 'Nu.'), ('BWP', 'Botswanan Pula', 'P'), ('BYN', 'Belarusian Ruble', 'Br'),
  ('BZD', 'Belize Dollar', '$'), ('CAD', 'Canadian Dollar', 'CA$'), ('CDF', 'Congolese Franc', 'FC'),
  ('CHF', 'Swiss Franc', 'CHF'), ('CLP', 'Chilean Peso', '$'), ('CNY', 'Chinese Yuan', 'CN¥'),
  ('COP', 'Colombian Peso', '$'), ('CRC', 'Costa Rican Colón', '₡'), ('CUP', 'Cuban Peso', '$'),
  ('CVE', 'Cape Verdean Escudo', '$'), ('CZK', 'Czech Koruna', 'Kč'), ('DJF', 'Djiboutian Franc', 'Fdj'),
  ('DKK', 'Danish Krone', 'kr'), ('DOP', 'Dominican Peso', 'RD$'), ('DZD', 'Algerian Dinar', 'DA'),
  ('EGP', 'Egyptian Pound', 'E£'), ('ERN', 'Eritrean Nakfa', 'Nfk'), ('ETB', 'Ethiopian Birr', 'Br'),
  ('EUR', 'Euro', '€'), ('FJD', 'Fijian Dollar', '$'), ('FKP', 'Falkland Islands Pound', '£'),
  ('GBP', 'British Pound', '£'), ('GEL', 'Georgian Lari', '₾'), ('GHS', 'Ghanaian Cedi', 'GH₵'),
  ('GIP', 'Gibraltar Pound', '£'), ('GMD', 'Gambian Dalasi', 'D'), ('GNF', 'Guinean Franc', 'FG'),
  ('GTQ', 'Guatemalan Quetzal', 'Q'), ('GYD', 'Guyanaese Dollar', '$'), ('HKD', 'Hong Kong Dollar', 'HK$'),
  ('HNL', 'Honduran Lempira', 'L'), ('HTG', 'Haitian Gourde', 'G'), ('HUF', 'Hungarian Forint', 'Ft'),
  ('IDR', 'Indonesian Rupiah', 'Rp'), ('ILS', 'Israeli New Shekel', '₪'), ('INR', 'Indian Rupee', '₹'),
  ('IQD', 'Iraqi Dinar', 'IQD'), ('IRR', 'Iranian Rial', 'IRR'), ('ISK', 'Icelandic Króna', 'kr'),
  ('JMD', 'Jamaican Dollar', '$'), ('JOD', 'Jordanian Dinar', 'JD'), ('JPY', 'Japanese Yen', '¥'),
  ('KES', 'Kenyan Shilling', 'KSh'), ('KGS', 'Kyrgystani Som', 'som'), ('KHR', 'Cambodian Riel', '៛'),
  ('KMF', 'Comorian Franc', 'CF'), ('KPW', 'North Korean Won', '₩'), ('KRW', 'South Korean Won', '₩'),
  ('KWD', 'Kuwaiti Dinar', 'KD'), ('KYD', 'Cayman Islands Dollar', '$'), ('KZT', 'Kazakhstani Tenge', '₸'),
  ('LAK', 'Laotian Kip', '₭'), ('LBP', 'Lebanese Pound', 'L£'), ('LKR', 'Sri Lankan Rupee', 'Rs'),
  ('LRD', 'Liberian Dollar', '$'), ('LSL', 'Lesotho Loti', 'L'), ('LYD', 'Libyan Dinar', 'LD'),
  ('MAD', 'Moroccan Dirham', 'MAD'), ('MDL', 'Moldovan Leu', 'L'), ('MGA', 'Malagasy Ariary', 'Ar'),
  ('MKD', 'Macedonian Denar', 'den'), ('MMK', 'Myanmar Kyat', 'K'), ('MNT', 'Mongolian Tugrik', '₮'),
  ('MOP', 'Macanese Pataca', 'MOP$'), ('MRU', 'Mauritanian Ouguiya', 'UM'), ('MUR', 'Mauritian Rupee', 'Rs'),
  ('MVR', 'Maldivian Rufiyaa', 'Rf'), ('MWK', 'Malawian Kwacha', 'MK'), ('MXN', 'Mexican Peso', 'MX$'),
  ('MYR', 'Malaysian Ringgit', 'RM'), ('MZN', 'Mozambican Metical', 'MT'), ('NAD', 'Namibian Dollar', '$'),
  ('NGN', 'Nigerian Naira', '₦'), ('NIO', 'Nicaraguan Córdoba', 'C$'), ('NOK', 'Norwegian Krone', 'kr'),
  ('NPR', 'Nepalese Rupee', 'Rs'), ('NZD', 'New Zealand Dollar', 'NZ$'), ('OMR', 'Omani Rial', 'OMR'),
  ('PAB', 'Panamanian Balboa', 'B/.'), ('PEN', 'Peruvian Sol', 'S/'), ('PGK', 'Papua New Guinean Kina', 'K'),
  ('PHP', 'Philippine Peso', '₱'), ('PKR', 'Pakistani Rupee', 'Rs'), ('PLN', 'Polish Zloty', 'zł'),
  ('PYG', 'Paraguayan Guarani', '₲'), ('QAR', 'Qatari Riyal', 'QR'), ('RON', 'Romanian Leu', 'lei'),
  ('RSD', 'Serbian Dinar', 'din'), ('RUB', 'Russian Ruble', '₽'), ('RWF', 'Rwandan Franc', 'RF'),
  ('SAR', 'Saudi Riyal', 'SR'), ('SBD', 'Solomon Islands Dollar', '$'), ('SCR', 'Seychellois Rupee', 'Rs'),
  ('SDG', 'Sudanese Pound', 'SDG'), ('SEK', 'Swedish Krona', 'kr'), ('SGD', 'Singapore Dollar', 'S$'),
  ('SHP', 'St. Helena Pound', '£'), ('SLE', 'Sierra Leonean Leone', 'Le'), ('SOS', 'Somali Shilling', 'Sh'),
  ('SRD', 'Surinamese Dollar', '$'), ('SSP', 'South Sudanese Pound', '£'), ('STN', 'São Tomé & Príncipe Dobra', 'Db'),
  ('SVC', 'Salvadoran Colón', '₡'), ('SYP', 'Syrian Pound', '£'), ('SZL', 'Swazi Lilangeni', 'E'),
  ('THB', 'Thai Baht', '฿'), ('TJS', 'Tajikistani Somoni', 'SM'), ('TMT', 'Turkmenistani Manat', 'm'),
  ('TND', 'Tunisian Dinar', 'DT'), ('TOP', 'Tongan Paʻanga', 'T$'), ('TRY', 'Turkish Lira', '₺'),
  ('TTD', 'Trinidad & Tobago Dollar', '$'), ('TWD', 'New Taiwan Dollar', 'NT$'), ('TZS', 'Tanzanian Shilling', 'TSh'),
  ('UAH', 'Ukrainian Hryvnia', '₴'), ('UGX', 'Ugandan Shilling', 'USh'), ('USD', 'US Dollar', '$'),
  ('UYU', 'Uruguayan Peso', '$'), ('UZS', 'Uzbekistani Som', 'soʻm'), ('VES', 'Venezuelan Bolívar', 'Bs.'),
  ('VND', 'Vietnamese Dong', '₫'), ('VUV', 'Vanuatu Vatu', 'VT'), ('WST', 'Samoan Tala', 'T'),
  ('XAF', 'Central African CFA Franc', 'FCFA'), ('XCD', 'East Caribbean Dollar', 'EC$'),
  ('XCG', 'Caribbean Guilder', 'Cg'), ('XOF', 'West African CFA Franc', 'CFA'), ('XPF', 'CFP Franc', 'CFPF'),
  ('YER', 'Yemeni Rial', 'YR'), ('ZAR', 'South African Rand', 'R'), ('ZMW', 'Zambian Kwacha', 'ZK'),
  ('ZWG', 'Zimbabwe Gold', 'ZiG')
) as c(code, name, symbol)
on conflict (code) do nothing;

create table public.categories (
  key text primary key check (key ~ '^[a-z]+(\.[a-z_]+)?$'),
  parent_key text references public.categories (key),
  name text not null check (char_length(name) between 1 and 40),
  icon text not null,          -- Phosphor icon name (T-018)
  color text not null check (color ~ '^#[0-9A-F]{6}$'),  -- 06-design-system.md category colours
  sort int not null,
  check ((parent_key is null) = (position('.' in key) = 0))
);

create index categories_parent_key_idx on public.categories (parent_key);

comment on table public.categories is 'Expense categories: parents (no dot) and sub-categories (parent.sub).';

insert into public.categories (key, parent_key, name, icon, color, sort) values
  ('food', null, 'Food', 'fork-knife', '#F97316', 10),
  ('groceries', null, 'Groceries', 'basket', '#22C55E', 20),
  ('travel', null, 'Travel', 'airplane-tilt', '#3B82F6', 30),
  ('rent', null, 'Rent', 'house', '#8B5CF6', 40),
  ('utilities', null, 'Utilities', 'lightning', '#EAB308', 50),
  ('shopping', null, 'Shopping', 'shopping-bag', '#EC4899', 60),
  ('entertainment', null, 'Entertainment', 'film-slate', '#14B8A6', 70),
  ('other', null, 'Other', 'dots-three-circle', '#64748B', 80),
  ('food.dining_out', 'food', 'Dining out', 'fork-knife', '#F97316', 11),
  ('food.takeaway', 'food', 'Takeaway', 'hamburger', '#F97316', 12),
  ('food.snacks', 'food', 'Snacks', 'cookie', '#F97316', 13),
  ('groceries.groceries', 'groceries', 'Groceries', 'basket', '#22C55E', 21),
  ('groceries.household', 'groceries', 'Household', 'broom', '#22C55E', 22),
  ('travel.flights', 'travel', 'Flights', 'airplane-tilt', '#3B82F6', 31),
  ('travel.train_bus', 'travel', 'Train & bus', 'train', '#3B82F6', 32),
  ('travel.cab_auto', 'travel', 'Cab & auto', 'taxi', '#3B82F6', 33),
  ('travel.fuel', 'travel', 'Fuel', 'gas-pump', '#3B82F6', 34),
  ('travel.hotel', 'travel', 'Hotel', 'bed', '#3B82F6', 35),
  ('travel.parking_tolls', 'travel', 'Parking & tolls', 'car', '#3B82F6', 36),
  ('rent.rent', 'rent', 'Rent', 'house', '#8B5CF6', 41),
  ('rent.maintenance', 'rent', 'Maintenance', 'wrench', '#8B5CF6', 42),
  ('utilities.electricity', 'utilities', 'Electricity', 'lightning', '#EAB308', 51),
  ('utilities.water', 'utilities', 'Water', 'drop', '#EAB308', 52),
  ('utilities.gas', 'utilities', 'Gas', 'flame', '#EAB308', 53),
  ('utilities.internet_phone', 'utilities', 'Internet & phone', 'wifi-high', '#EAB308', 54),
  ('utilities.subscriptions', 'utilities', 'Subscriptions', 'repeat', '#EAB308', 55),
  ('shopping.clothing', 'shopping', 'Clothing', 't-shirt', '#EC4899', 61),
  ('shopping.electronics', 'shopping', 'Electronics', 'device-mobile', '#EC4899', 62),
  ('shopping.gifts', 'shopping', 'Gifts', 'gift', '#EC4899', 63),
  ('shopping.other', 'shopping', 'Other shopping', 'shopping-bag', '#EC4899', 64),
  ('entertainment.movies', 'entertainment', 'Movies', 'film-slate', '#14B8A6', 71),
  ('entertainment.events', 'entertainment', 'Events', 'ticket', '#14B8A6', 72),
  ('entertainment.games', 'entertainment', 'Games', 'game-controller', '#14B8A6', 73),
  ('entertainment.sports', 'entertainment', 'Sports', 'soccer-ball', '#14B8A6', 74),
  ('other.general', 'other', 'General', 'receipt', '#64748B', 81),
  ('other.medical', 'other', 'Medical', 'first-aid-kit', '#64748B', 82),
  ('other.education', 'other', 'Education', 'graduation-cap', '#64748B', 83),
  ('other.services', 'other', 'Services', 'toolbox', '#64748B', 84)
on conflict (key) do nothing;
