# WebKumir
For kumir competitions


## V2.0 Files
- \WebKumirFiles – Рабочая папка со всеми файлами
    - \WebKumirFiles\autosaves – Сохранения для возможного бекапа
    - \WebKumirFiles\index
        - \WebKumirFiles\index\Files – Не используется, предназначена для файлов (при большом желание их можно отображать в tab задачи)
        - \WebKumirFiles\index\js
            - admin.js – Теперь это скрипт для учителя, он может следующее: удалять/добавлять учеников в группу + удалять/создавать турниры
            - admin_of_admin.js – Новый скрипт, отвечает за действия осуществимые консолью до 2.0 (все действия с проектами, программами, аками и тд)
            - js.js – Всё связаное с клиентом, отрисовка карты + редактор и тд
            - kumir.js – Транслятор + лаунчер
            - kumir_helper.js – Все функции для лаунчера (подгружается динамически в kumir.js)
        - \WebKumirFiles\index\lib – Библиотеки для редактора
        - \WebKumirFiles\index\split – Используется в редакторе, возможно, будет удалено когда-нибудь
        - \WebKumirFiles\index\tileset – Файлы для клиента, изображения + видео
        - \WebKumirFiles\index\trackbar – Используется в редакторе, возможно, будет удалено когда-нибудь
        - admin.html – Главная страница учителя
        - admin_add_in_group.html – Добовление в группу учителя
        - admin_del_from_group.html – Удаление из группы учителя
        - admin_of_admin.html – Отвечает за действия осуществимые консолью до 2.0(все действия с проектами, программами, аками и тд)
        - admin_run_tur.html – Запуск турниров
        - index.html – Всё связаное с клиентом, отрисовка карты + редактор и тд
        - login.html – Тут и так всё понятно
        - register.html – Регистрация
        - select_server.html – Выбор сервера
    - \WebKumirFiles\projects - Тут и так всё понятн

## Протокол взаимодействия клиент-сервер
- Клиент запрашивает разрешение на запрос, на что сервер возвращает случайную строку (example: fe9a74a415156212e958c382a34322b1) (здесь сервер запоминает какую команду необходимо выполнить и какую строку он отослал)
- Клиент шифрует полученную строку со своим паролём и запрашивает у сервера выполнение необходимой команды (пример запроса клиента: 
\\_(сервер, для некоторых команд не обязательно писать )_\\protect\\894db3c219fbffdedde0aef4673c150b.txt)
- При получение такого типа запрос сервер шифрует пароль пользователя и строку, которую отсылал в пункте 1 и проверяет что ему пришло. Если всё совпало, то он выполняет эту команду и отсылает ответ команды

