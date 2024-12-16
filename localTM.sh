#!/bin/bash

# Функция для обнуления переменных
obnulenie() {
    hostname=0
    datetime=0
    adress=0
    version_os=0
    version_core=0
    cpu=0
    ozu=0
    disk=0
    auth_errors=0
    remote_num=0
    in_local=0
    ipp=0
    ipp_pass=0
    ipp_user=0
}

obnulenie

# Проверка доступа к сети
checking_network() {
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "Ошибка: Нет доступа к сети."
        exit 1
    fi
}

# Установка sshpass
install_sshpass() {
    if command -v pacman &> /dev/null; then
        if ! pacman -Qs "sshpass" > /dev/null 2>&1; then
            checking_network
            sudo pacman -S --noconfirm "sshpass" >/dev/null 2>&1
        fi
    elif command -v apt &> /dev/null; then
        if ! dpkg -l | grep -q "sshpass"; then
            checking_network
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y "sshpass" >/dev/null 2>&1
        fi
    elif command -v yum &> /dev/null; then
        if ! rpm -q "sshpass" > /dev/null 2>&1; then
            checking_network
            sudo yum install -y "sshpass" >/dev/null 2>&1
        fi
    elif command -v dnf &> /dev/null; then
        if ! dnf list installed "sshpass" > /dev/null 2>&1; then
            checking_network
            sudo dnf install -y "sshpass" >/dev/null 2>&1
        fi
    elif command -v zypper &> /dev/null; then
        if ! zypper se --installed-only | grep -q "sshpass"; then
            checking_network
            sudo zypper install -y "sshpass" >/dev/null 2>&1
        fi
    else
        echo "Пакетный менеджер не найден."
    fi
}

# Установка sshpass
install_sshpass

# Приветствие
whiptail --title "localTM" --msgbox "Добро пожаловать в localTM. Для продолжения, нажмите ОК" 8 78

# Проверка, находится ли компьютер в одной сети
#if whiptail --title "Проверка сети" --yes-button "Да" --no-button "Нет" --yesno "Находится ли компьютер в одной сети?" 10 60; then
    in_local=1
#else
    #in_local=0
#fi

# Количество машин
remote_num=$(whiptail --title "Выбор количества компьютеров" --menu "Выберите количество компьютеров:" 15 50 6 \
    "1" "Один компьютер" \
    "2" "Два компьютера" \
    "3" "Три компьютера" \
    "4" "Четыре компьютера" \
    "5" "Пять компьютеров" \
    "6" "Шесть компьютеров" 3>&1 1>&2 2>&3)

# Массивы для хранения данных
declare -a ipps
declare -a ipp_users
declare -a ipp_passes
declare -a cpu_loads

# Ввод данных и проверка соединения
for ((i = 1; i <= remote_num; i++)); do
    while true; do
        # Ввод IP
        ipp=$(whiptail --inputbox "Введите IP для компьютера №$i:" 10 60 3>&1 1>&2 2>&3)
        ipps[i-1]="$ipp"

        # Ввод имени пользователя
        ipp_user=$(whiptail --inputbox "Введите имя пользователя для компьютера №$i:" 10 60 3>&1 1>&2 2>&3)
        ipp_users[i-1]="$ipp_user"

        # Ввод пароля
        ipp_pass=$(whiptail --passwordbox "Введите пароль для компьютера №$i:" 10 60 3>&1 1>&2 2>&3)
        ipp_passes[i-1]="$ipp_pass"

        # Попытка подключения через SSH с таймаутом
        timeout 15 sshpass -p "$ipp_pass" ssh -o StrictHostKeyChecking=no "$ipp_user@$ipp" "exit" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            if whiptail --title "Ошибка подключения" --yesno "Не удалось подключиться к $ipp. Хотите повторить ввод данных?" 10 60; then
                continue  # Повторный ввод данных
            else
                whiptail --title "Завершение" --msgbox "Скрипт будет завершен." 10 60
                exit 1  # Завершение скрипта
            fi
        else
            whiptail --title "Успех" --msgbox "Успешно подключились к $ipp." 10 60
            break  # Успешное подключение, выход из цикла
        fi
    done
done

# Функция для сбора данных о системе
collect_system_info() {
    : > /tmp/system_info.txt  # Очистка временного файла перед началом
    max_cpu=0
    max_cpu_index=0

    for ((i = 0; i < ${#ipps[@]}; i++)); do
        if [[ -n "${ipps[$i]}" ]]; then
            hostname=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "hostname" 2>/dev/null)
            datetime=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "date" 2>/dev/null)
            adress=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "hostname -I" 2>/dev/null)
            version_os=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "lsb_release -d | cut -f2-" 2>/dev/null)
            version_core=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "uname -r" 2>/dev/null)
            cpu=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "vmstat 1 2 | tail -1 | awk '{print 100 - \$15}'" 2>/dev/null)
            ozu_percentage=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "free -m | awk 'NR==2{printf \"%.2f\", (\$3/\$2)*100}'" 2>/dev/null)
            ozu=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "free -m | awk 'NR==2{printf \"%.2f%% (%s/%s MB)\", (\$3/\$2)*100, \$3, \$2}'" 2>/dev/null)
            ozu_percentage_int=$(echo $ozu_percentage | awk -F'.' '{print $1}')
            disk=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "df -h / | awk 'NR==2{printf \"%s (%s/%s)\", \$5, \$3, \$2}'" 2>/dev/null)
            sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "echo '${ipp_passes[$i]}' | sudo -S chmod 644 /var/log/auth.log" 2>/dev/null
            auth_errors=$(sshpass -p "${ipp_passes[$i]}" ssh -o StrictHostKeyChecking=no "${ipp_users[$i]}@${ipps[$i]}" "grep 'Failed password' /var/log/auth.log | wc -l" 2>/dev/null)

            cpu_loads[i]=$cpu
            if (( $(echo "$cpu > $max_cpu" | bc -l) )); then
                max_cpu=$cpu
                max_cpu_index=$i
            fi

            echo "Компьютер №$((i+1)):" >> /tmp/system_info.txt
            echo "Имя хоста: $hostname" >> /tmp/system_info.txt
            echo "Дата и время: $datetime" >> /tmp/system_info.txt
            echo "IP адрес: $adress" >> /tmp/system_info.txt
            echo "Версия ОС: $version_os" >> /tmp/system_info.txt
            echo "Версия ядра: $version_core" >> /tmp/system_info.txt
            echo "CPU загрузка: $cpu% (|$(printf "%0.s|" $(seq 1 $(($cpu / 2)))))" >> /tmp/system_info.txt
            echo "ОЗУ загрузка: $ozu (|$(printf "%0.s|" $(seq 1 $(($ozu_percentage_int / 2)))))" >> /tmp/system_info.txt
            echo "Место на диске: $disk" >> /tmp/system_info.txt
            echo "Ошибки авторизации: $auth_errors" >> /tmp/system_info.txt
            echo "----------------------------------------" >> /tmp/system_info.txt
        fi
    done

    # Подсветка наиболее загруженного компьютера
    max_cpu_line=$(grep -n "Компьютер №$((max_cpu_index+1)):" /tmp/system_info.txt | cut -d: -f1)
    sed -i "${max_cpu_line}s/.*/<span class=\"highlight\">&<\/span>/" /tmp/system_info.txt
}

# Функция для корректного завершения работы скрипта
cleanup() {
    echo "Завершаем работу скрипта..."
    pkill -P $$
    echo "Готово!"
    exit 0
}

# Отслеживание сигнала прерывания для корректного завершения
trap cleanup SIGINT

# Создание веб-сервера для отображения данных
create_web_server() {
    while true; do
        collect_system_info

        echo "<html><head><meta charset='UTF-8'><style> .highlight {color: red;} pre {font-family: monospace; line-height: 1.5;} </style></head><body><pre id='content'>" > index.html

        # Вставка содержимого временного файла в HTML-документ
        cat /tmp/system_info.txt >> index.html

        echo "</pre>
        <script>
            function fetchUpdates() {
                fetch('index.html')
                .then(response => response.text())
                .then(data => {
                    document.getElementById('content').innerHTML = data;
                });
            }
            setInterval(fetchUpdates, 5000);
        </script></body></html>" >> index.html

        sleep 1
    done
}

# Запуск веб-сервера
python3 -m http.server 8000 >/dev/null 2>&1 &

# Запуск функции для создания веб-сервера
create_web_server &

# Открытие окна с ссылкой на веб-страницу
whiptail --title "Скрипт завершен" --msgbox "Скрипт завершен. Вы можете просматривать данные на веб-странице по адресу: http://localhost:8000" 10 60

# Ожидание сигнала прерывания
while true; do
    sleep 1
done

obnulenie