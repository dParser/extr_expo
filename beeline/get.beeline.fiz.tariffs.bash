#!/bin/bash
# v.1.0
#
# 	1. С помощью скрипта regionhood получает по каждому региону URL страницы,
# содержащей сводное описание т.планов линейки "Всё N".
#?	2. Из каждой такой "слайдерной" страницы извлекает ссылки на страницы
#? конкретных т.планов.
#?	3. Из каждой страницы конкретного т.плана извлекает фрагмент с описанием
#? пакета минут+Гб и зоны его действия и помещает во временный файл RAWFILE.
#?	4. Приводит названия регионов к стандартным значениям, согласно справочнику regionas.etalonas.txt
#
# Параметры командной строки: -
#	--s4	- (Stage 4) сразу же переходит на обработку п.4. Обработка ранее полученного RAWFILE

# Переменные:
extracto_dir="EL_EXTRACTO/"		# Каталог, в котором хранятся экстракты (выборки) из описаний т.планов
arc_dir="EL_EXTRACTO/ARC/"		# Каталог, в котором хранятся архивные экстракты (выборки) из описаний т.планов

### 0. Обработка параметров ком. строки:
if [[ $* =~ --s4 ]]
then
	# ... если передан параметр, переходить сразу на п.4
	stage4=1
else
	stage4=0
fi

if [ $stage4 -ne 1 ]
then
	### 1.
	# По каждому региону получить URL страницы, содержащей описание т.планов линейки "Всё N".
	# Перенаправлять стандартный вывод скрипта regionhood на REGIONHOODOUT:
#	eval >REGIONHOODOUT ./regionhood.bash  -s http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/ -a regiones.part.txt
	eval >REGIONHOODOUT ./regionhood.bash  -s http://astrakhanskaya-obl.beeline.ru/customers/products/mobile/tariffs/ -a regiones.txt

	### 2.
	# Наименование колонок:
	echo -e "#ID_Региона\tРегион\tТариф(.title)\tURL(.link)" > SLIDERSPAGE

	# Сообщение:
	echo
	echo '==================================================================================='
	echo 'Со сводной страницы каждого региона извлечь ссылки на описания конкретных т.планов:'
	#    Пример извлеченной ссылки: http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/details/vse-1/:

	while IFS=$'\x09' read region_id region href; do
		if [[ $region_id =~ ^# ]]
		then
		# удалить "шапку" входного файла
			continue
		fi
		echo
		echo "Выполняется для: $region"
		# curl		- HTML контент
		#	|sed	- выделяем из HTML строку, содержащую JSON
		#	|sed 	- выделяем из строки JSON структуру (от "{" до "}")
		#	|jq		- извлечь из JSON для каждого тарифа следующие поля: <.title>,<.link> (название и ссылку на описание).
		#				Примечание: JSON - это упрощенно массив из элементов двух типов - "type": "tariff" и "type": "family". 
		#								В связи с этим используется конструкция "//".
		#	|sed		- склеить поля <.title>,<.link> в одну строчку
		curl --connect-timeout 500 --max-time 500 $href | 	# --connect-timeout <sec>, --max-time <seconds>
			sed -nr "/beeline.pages.TariffsCatalog/p" |
			sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
			jq -r '. .data .list[]|(.title,.link) // (.groups[]|.tariffs[]|.title,.link)' |
			sed '$!N;s/\n/\t/' |
			sed -r "s%(.+)\t(.+)%$region_id\t$region\t\1\thttp://$region\.beeline\.ru\2%" >> SLIDERSPAGE
	done <REGIONHOODOUT

	### 3. Формировать RAWFILE (без id тарифа, id зоны, id ед.изм.)
	# Наименование колонок:
	echo -e "#Регион_ID\tРегион\tТариф\tЗоны_действия(.label)\tЗначение(.value)\tЕд_изм(.unit)\tПодробно(.legal)" > RAWFILE

	# Сообщение:
	echo
	echo '==============================================================================='
	echo 'Из каждой страницы конкретного т.плана извлекает'
	echo -e "Регион_ID\tРегион\tТариф\tЗоны_действия\tЗначение\tЕд_изм\tПодробно"

	while IFS=$'\x09' read region_id region tariff_name href; do
		if [[ $region_id =~ ^# ]]
		then
		# удалить "шапку" входного файла
			continue
		fi
		# curl		- HTML контент
		#	|sed	- выделяем из HTML строку, содержащую JSON
		#	|sed	- выделяем из строки JSON структуру (от "{" до "}")
		#	|sed	- удаляем \n, встречающихся внутри тегов]
		#	|jq		- извлечь из JSON следующие поля: <.label>,<.value>,<unit>,<legal> - Описание пакета, Значение, Ед.изм.,Подробно 
		#	|sed	- "склеиваем" четыре поля, лежащих  в трех идущих др. за др. строчках
		#	|sed	- удаляем "/мес" из ед.изм.
		#	|sed	- меняем &nbsp; на пробел.
		#	|sed	- удаляем <nobr> и </nobr>.
		#	|sed	- меняем \xa0 (в кодах UTF-8) на обычный пробел.
		#	|sed	- формируем запись
		#	>>		- окончательную запись вносим в RAWFILE
		curl --connect-timeout 500 --max-time 500 $href | # --connect-timeout <sec>, --max-time <seconds>
			sed -nr "/beeline.pages.TariffCard/p" |
			sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
			sed -r 's/\\n//g' |
#			jq -r '. .data .productParameters[]|.label,.value,.unit' |
			jq -r '. .data .descriptions[]|select(.title=="Каждый месяц вы получаете")|.content[]|.label,.value,.unit,.legal' |
			sed '$!N;$!N;$!N;s/\n/\t/g' |
			sed -r 's%/мес%%' |
			sed -r 's/&nbsp;/ /g' |
			sed -r 's%</?nobr>%%g' |
			sed 's/\xc2\xa0/\x20/g'  |
			sed -r "s/(.+)\t(.+)\t(.+)\t(.+)/$region_id\t$region\t$tariff_name\t\1\t\2\t\3\t\4/" >> RAWFILE
	done <SLIDERSPAGE
fi

### 4. Формировать окончателный файл экстракт ${extracto_dir}beeline.fiz.txt
## 4.1. Если файл ${extracto_dir}.beeline.fiz.txt существует...
if [ ! -a ${extracto_dir}.beeline.fiz.txt ]
then
	# ... переименовать существующий, дополнив название временным штампом yyyyMMdd.hhmmss
	timestamp=`date +%Y%m%d.%k%M%S`
	echo
	echo "Файл ${extracto_dir}.beeline.fiz.txt существует. Переименовываем его в ${arc_dir}$timestamp.beeline.fiz.txt"
	echo
	cp ${extracto_dir}beeline.fiz.txt ${arc_dir}$timestamp.beeline.fiz.txt
fi	# $stage4 / --s4

## 4.2. Наименование колонок:
echo -e "Регион_ID\tРегион\tТариф_ID\tТариф\tЗоны_действия_ID\tЗоны_действия\tЗначение\tЕд_изм_ID\tЕд_изм\tПодробно" > ${extracto_dir}beeline.fiz.txt

# Сообщение:
echo
echo '==============================================================================='
echo 'Добавляет значения id тарифа, id зоны, id ед.изм.'

while IFS=$'\x09' read region_id region tariff zone volume edizm legal; do
	if [[ $region_id =~ ^# ]]
	then
	# удалить "шапку" входного файла
		continue
	fi
# Добавляет id тарифа
	tariff_id='-'	# инициация условным знаком '-'. Если искомого тарифа не будет в справочнике его id "автоматом" будет "-".
	while IFS=$'\x09' read tariff_id_lst tariff_lst; do
	if [[ $tariff == $tariff_lst ]]
		then
		tariff_id=$tariff_id_lst
	fi
	done <tariffs.txt
# Добавляет id зоны и добавляет окончательную запись в файл beeline.fiz.txt:
	zone_id='-'	# инициация условным знаком '-'. Если искомой зоны не будет в справочнике ее id "автоматом" будет "-".
	zone_legal="$zone$legal"
	while IFS=$'\x09' read zone_id_lst zone_red zone_oper_lst; do
#		if [[ $zone == $zone_oper_lst ]]
		if [[ $zone_legal =~ $zone_oper_lst ]]
		then
			zone_id=$zone_id_lst
			echo 	-e "$region_id\t$region\t$tariff_id\t$tariff\t$zone_id\t$zone\t$volume\t$edizm\t$legal" >> ${extracto_dir}beeline.fiz.txt
		fi		
	done <zones.txt
	if [[ $zone_id == '-' ]]
	then
		# записать в случае, если zone_id = "-": 
		echo 	-e "$region_id\t$region\t$tariff_id\t$tariff\t$zone_id\t$zone\t$volume\t$edizm\t$legal" >> ${extracto_dir}beeline.fiz.txt
	fi
done <RAWFILE

#### 4.
## "Грязные" названия регионов привести к стандартным:
#standart_name=""
#same_name=""	# Название региона предыдущей записи (кэш)
#
## 4.1. Если файл ${extracto_dir}.beeline.fiz.txt существует...
#if [ ! -a ${extracto_dir}.beeline.fiz.txt ]
#then
#	# ... переименовать существующий, дополнив название временным штампом yyyyMMdd.hhmmss
#	timestamp=`date +%Y%m%d.%k%M%S`
#	echo
#	echo "Файл ${extracto_dir}.beeline.fiz.txt существует. Переименовываем его в ${arc_dir}$timestamp.beeline.fiz.txt"
#	echo
#	cp ${extracto_dir}beeline.fiz.txt ${arc_dir}$timestamp.beeline.fiz.txt
#fi
#echo -n > ${extracto_dir}beeline.fiz.txt
#while IFS=$'\x09' read region_id region name call internet cost; do
#	echo "Название региона '$region' приводится к стандартному значению."
#	if [[ $region != $same_name ]]
#	then
#		standart_name=$(./get_standart_name.bash $region)
#		same_name=$region
#	fi
##	echo -e "$(./get_standart_name.bash $region)\t$name\t$call\t$internet\t$cost" >> ${extracto_dir}beeline.fiz.txt
#	echo -e "$standart_name\t$name\t$call\t$internet\t$cost" >> ${extracto_dir}beeline.fiz.txt
#done <RAWFILE


# ПРИМЕРЫ обработки JSON при помощи jq.
#
# 1. Со страницы сайта со списком тарифов выделить поля 
#	"Название тарифа", "Пакет интернет", "Пакет минут", "Пакет СМС", "Ссылка на описание тарифа":
#	1.1. Нотация для bash-скрипта:
# curl http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/ |
# sed -nr "/beeline.pages.TariffsCatalog/p" |
# sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
# jq '. .data .list[]|select(.type=="family")|.groups[]|.tariffs[]|.title,.parameters.internetPackage.value, .parameters.minutePackage.value, .link'
#	1.2. Нотация для командной строки:
# curl http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/ | sed -nr "/beeline.pages.TariffsCatalog/p" | sed -rn "s/[^\{]+(\{.+\}).+/\1/p" | jq '. .data .list[]|select(.type=="family")|.groups[]|.tariffs[]|.title,.parameters.internetPackage.value, .parameters.minutePackage.value, .link'
#
# 2. С той же страницы. Выделить поля "Название тарифа", "Ссылка на описание тарифа" по select(.type=="family"):
# curl http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/ |
# sed -nr "/beeline.pages.TariffsCatalog/p" |
# sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
# jq '. .data .list[]|select(.type=="family")|.groups[]|.tariffs[]|.title,.link'
#
# 3. С той же страницы. Выделить поля "Название тарифа", "Ссылка на описание тарифа" по select(.type=="tariff"):
# curl http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/ |
# sed -nr "/beeline.pages.TariffsCatalog/p" |
# sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
# jq '. .data .list[]|select(.type=="tariff")|.title,.link'


# curl --connect-timeout 500 --max-time 500 $href | # --connect-timeout <sec>, --max-time <seconds>
#			sed -nr "/beeline.pages.TariffCard/p" |
#			sed -rn "s/[^\{]+(\{.+\}).+/\1/p" |
#			jq -r '. .data .productParameters[]|.label,.value,.unit'
# curl --connect-timeout 500 --max-time 500 http://moskva.beeline.ru/customers/products/mobile/tariffs/details/vse-za-1450-postoplatnyy/ | sed -nr "/beeline.pages.TariffCard/p" | sed -rn "s/[^\{]+(\{.+\}).+/\1/p" | jq -r '. .data .productParameters[]|.label,.value,.unit'