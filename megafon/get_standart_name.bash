#!/bin/bash
# v.1.0
#
# На входе получает "сырое" наименование, ищет по справочнику и выдает его стандартный вариант.

# Параметры командной строки (сначала заменяемое слово (фразу), а, после, остальные параметры): -
#	<raw_name>	- "сырое" наименование
#	--def <файл справочника>	- файл хешей "raw_name"->"standart_name". По умолчанию это regionas.etalonas.txt
#	--verb	- выводить сообщения о ходе работы скрипта.
#	--

DEFFILE="regionas.etalonas.txt"	# Полное имя файла стандартных имен.
same_name=""	# Название региона предыдущей записи (кэш)
param=$*		# Параметры ком. строки

### 1. Обработка параметров ком.строки:
#1.1. --verb. Увеличена многословность скрипта
if [[ $param =~ --verb ]]
then
	verboseness='1'
fi

#1.2. --def. Задан другой справочник...
if [[ $param =~ --def\ +([^\ ]+) ]]
then
	# ... работать по нему:
	DEFFILE=${BASH_REMATCH[1]}
fi

# Существует ли файл справочника?
if [[ ! -a $DEFFILE ]]
	then
					# Пояснительное сообщение
					if [[ $verboseness == '1' ]]
					then
						echo "Файла $DEFFILE не существует."
					fi
		exit
	fi

# Пояснительное сообщение
if [[ $verboseness == '1' ]]
then
	echo
	echo "Будет использован справочник: $DEFFILE"
	echo
fi


#1.3. <raw_name> Получить "сырое" значение:
raw_name=`echo $param | sed -r "s/\ +--.+//"`
standart_name=$raw_name
if [[ $verboseness == '1' ]]
then
	echo "Искать замену для: $raw_name"
	echo
	echo "Просмотр записей:"
fi

### 2. Поиск по справочнику
if [[ $same_name != $raw_name ]]
then
	while read line; do
		
		line_iconv=`echo $line | iconv -f Windows-1251 -t UTF-8 | sed -r "s/[\r\n]//"`
						# Пояснительное сообщение
						if [[ $verboseness == '1' ]]
						then
							echo $line_iconv
						fi
		same_name=$raw_name
		if [[ $line_iconv =~ $raw_name=(.+) ]]
		then
			standart_name=${BASH_REMATCH[1]}
			break
		fi
	done <$DEFFILE
fi

# Пояснительное сообщение
if [[ $verboseness == '1' ]]
then
	echo
	echo "Замена найдена:"
fi

echo $standart_name