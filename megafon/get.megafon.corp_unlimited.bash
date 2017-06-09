#!/bin/bash
# v.1.0
#
# 	1. С помощью скрипта regionhood получает по каждому региону URL страницы,
# содержащей сводное описание т.плана "Корп. безлимит". Особенность этого
# описания заключается в двух слайдерах - слайдер для звонков
# и слайдер для интернета.
#	2. Из каждой такой "слайдерной" страницы извлекает ссылки на страницы
# конкретных т.планов.
#	3. Из каждой страницы конкретного т.плана извлекает фрагмент с описанием
# пакета минут+Гб и зоны его действия и помещает во временный файл RAWFILE.
#	4. Приводит названия регионов к стандартным значениям, согласно справочнику regionas.etalonas.txt
#
# Параметры командной строки: -

# Переменные:
extracto_dir="EL_EXTRACTO/"		# Каталог, в котором хранятся экстракты (выборки) из описаний т.планов
arc_dir="EL_EXTRACTO/ARC/"		# Каталог, в котором хранятся архивные экстракты (выборки) из описаний т.планов

### 1.
# По каждому региону получить URL страницы, содержащей описание т.плана "Корп. безлимит"
# в виде двух слайдеров - для звонков и для интернета.
# Перенаправлять стандартный вывод скрипта regionhood на REGIONHOODOUT:
eval >REGIONHOODOUT ./regionhood.bash -s http://amur.megafon.ru/corporate/mobile/tariffs/alltariffs/corp_unlimited/ -a regiones.txt

### 2.
# Очистить файл вывода:
echo -n > SLIDERSPAGE
echo 'Со "слайдерной" страницы каждого региона извлечь ссылки на описания конкретных т.планов:'
#    Пример извлеченной ссылки: http://amur.megafon.ru/corporate/mobile/tariffs/alltariffs/corp_unlimited/korporativnij_bezlimit_700_minut_dr_i_3_gb_dr.html:
while read aliase href; do
echo "Выполняется для: $aliase"
# Перенаправлять стандартный вывод на SLIDERSPAGE:
	curl $href | grep >>SLIDERSPAGE -E href=\"http://.+megafon.ru/corporate/mobile/tariffs/alltariffs/corp_unlimited/korporativnij_bezlimit # >> megafon-bk_html_special.txt
#	exit
#	break
done <REGIONHOODOUT

### 3. Формировать RAWFILE
# Наименование колонок:
echo -e "Регион\tНаименование опции\tПакет минут\tПакет интернета\tСтоимость опции" > RAWFILE
echo "Из каждой страницы конкретного т.плана извлекает фрагмент с описанием пакета:"
while read line_1; do
	# echo|sed		- из тега выделить ссылку типа "http://..."
	#	  |curl		- по этой ссылке скачать HTML контент
	#	  |sed		- из него выделить два фрагмента - с наименованием региона и описанием тарифа
	#	  |tr 		- превратить вывод в одну строку (удалить все символы конца строки)
	#	  |sed		- извлечь следующие поля: <Регион> <Наименование опции> <Пакет минут> <Пакет интернета> <Стоимость опции>
	#	  >			- записать в предварительный файл ("грязные" наименования регионов)
	curl --connect-timeout 500 --max-time 500 `echo $line_1 | sed -r 's/[^\"]+\"([^\"]+)".*/\1/'` | 	# --connect-timeout <sec>, --max-time <seconds>
		sed -n -e '/<title>/,/<\/title>/p' -e '/<tariff/,/b-b2b-page-actions__item b-b2b-page-actions__item_mail/p' |
		tr -d '\n' |
		 sed -r 's/.+;\ *([^\ ;\t<]+(\ [^\ ;\t<]+)*)[\t\ ]*<\/title>.+title=\"Корпоративный\ безлимит:\ (([0-9]+)\ минут\ \([^\)]+\)\ и\ ([0-9]+)\ Гб\ \([^\)]+\))\".+?monthly_payment\"\ data-value=\"([0-9]+)\".+/\1\t\3\t\4\t\5\t\6\n/' >> RAWFILE
done <SLIDERSPAGE

### 4.
# "Грязные" названия регионов привести к стандартным:
standart_name=""
same_name=""	# Название региона предыдущей записи (кэш)

# 4.1. Если файл ${extracto_dir}.megafon.corp_unlimited.txt существует...
if [ ! -a ${extracto_dir}.megafon.corp_unlimited.txt ]
then
	# ... переименовать существующий, дополнив название временным штампом yyyyMMdd.hhmmss
	timestamp=`date +%Y%m%d.%k%M%S`
	echo
	echo "Файл ${extracto_dir}.megafon.corp_unlimited.txt существует. Переименовываем его в ${arc_dir}$timestamp.megafon.corp_unlimited.txt"
	echo
	cp ${extracto_dir}megafon.corp_unlimited.txt ${arc_dir}$timestamp.megafon.corp_unlimited.txt
fi
echo -n > ${extracto_dir}megafon.corp_unlimited.txt
while IFS=$'\x09' read region name call internet cost; do
	echo "Название региона '$region' приводится к стандартному значению."
	if [[ $region != $same_name ]]
	then
		standart_name=$(./get_standart_name.bash $region)
		same_name=$region
	fi
#	echo -e "$(./get_standart_name.bash $region)\t$name\t$call\t$internet\t$cost" >> ${extracto_dir}megafon.corp_unlimited.txt
	echo -e "$standart_name\t$name\t$call\t$internet\t$cost" >> ${extracto_dir}megafon.corp_unlimited.txt
done <RAWFILE
