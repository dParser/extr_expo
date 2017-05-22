#!/bin/bash
# v.1.0
#
# ДЛЯ БИЛАЙН
#
# 	На основании строки (URL), заданной в качестве образца,
# формирует множество строк (URLs), отличающихся от неё и от всех других
# небольшим фрагментом (алиасом региона).
# Набор таких фрагментов (алиасов регионов) для каждой из строк (URL) хранится
# в виде массива.
#
# 	Пояснение на примере сайта Билайн:
#	Имеем массив алиасов регионов, принятых у оператора:
#		altayskiy-kr, amurskaya-obl, arkhangelskaya-obl..., yaroslavskaya-obl
#	В качестве образца, имеем строку URL для Амурской области, алиас, которой - amur:
#		http://amurskaya-obl.beeline.ru/customers/products/mobile/tariffs/
#	На выходе получаем список URL для всех остальных регионов, отличающихся в части алиаса:
#		http://altayskiy-kr.beeline.ru/customers/products/mobile/tariffs/
#		http://amurskaya-obl.beeline.ru/customers/products/mobile/tariffs/
#		http://arkhangelskaya-obl.beeline.ru/customers/products/mobile/tariffs/
#		...
#		http://yaroslavskaya-obl.beeline.ru/customers/products/mobile/tariffs/

# Параметры командной строки:
#	-s <string>  	строка (URL) образец
#	-a <file name>  файл содержащий массив алиасов в формате <aliase>[, <name>]
#	-f 				сохранять результат в файл regionhood.log

example="-"		# Cтрока образец. Если не задана, ожидается ввод с клавиатуры
aliaseFile="-"	# Файл алиасов. Если имя не задано, ожидается ввод с клавиатуры
exampleOK=""	# Устанавливается в "1", если "правильная" строка образец, т.е.
				# содержит один из алиасов
exampleAliase=""	# Алиас, содержащийся в строке образце

# Получить строку образец:
if [[ $* =~ -s\ *([^\ ]+) ]]
then
	# ... из ком. строки
	example=${BASH_REMATCH[1]}
else
	# ... со стандартного устр. ввода (клав.)
	echo 'Enter example string (URL):'
	read example
fi

# Получить имя файла, содержащего массив алиасов:
if [[ $* =~ -a\ *([^\ ]+) ]]
then
	# ... из ком. строки
	aliaseFile=${BASH_REMATCH[1]}
else
	# со стандартного устр. ввода (клав.)
	echo 'Enter aliases file name:'
	read
fi

ALIASEFILE=$aliaseFile
# Последовательно перебирая все алиасы из массива (файла), выяснить
while IFS=$'\x09' read region_id region; do
	if [[ $example =~ \/$region ]]
	# ... содержит ли строка образец, один из алиасов?
	then
	# Если содержит, то установить признак и выйти из цикла
		exampleAliase=$region
		exampleOK=1
		break
	fi
done <$ALIASEFILE 

if [[ exampleOK -ne 1 ]]
# Если не содержит,
then
	# ... то закончить ни чего не делая
	echo "Nothing to do"
	echo "Not suitable example string (URL)"
	exit
fi

# 
ALIASEFILE=$aliaseFile

if [[ $* =~ \ +-f\ * ]]
# Если в ком. строке есть переключатель -f, то
then
# ... выводить в файл результаты следующего перебора:
	# Наименование колонок:
	echo -e "#ID_Региона\tРегион\tURL" > regionhood.log
	# Последовательно перебирая все алиасы из массива (файла),
	while IFS=$'\x09' read region_id region; do
		if [[ $region_id =~ ^# ]]
		then
		# удалить "шапку" входного файла
			continue
		fi
		# ... сформировать и сохранить в файл новую строку (URL) 
		# с соответствующим алиасом:
		echo $example | sed -r "s/(.*)${exampleAliase}(.*)/$region_id\t$region\t\1$region\2/" >> regionhood.log
	done <$ALIASEFILE 
	# Завершить скрипт по окончании перебора:
	exit
fi

# Последовательно перебирая все алиасы из массива (файла),
# Наименование колонок:
echo -e "#ID_Региона\tРегион\tURL"
# Последовательно перебирая все алиасы из массива (файла),
while IFS=$'\x09' read region_id region; do
	if [[ $region_id =~ ^# ]]
	then
	# удалить "шапку" входного файла
		continue
	fi
	# ... сформировать и вывести на STDOUT новую строку (URL)
	# с соответствующим алиасом:
	echo $example | sed -r "s/(.*)${exampleAliase}(.*)/$region_id\t$region\t\1$region\2/"
done <$ALIASEFILE 