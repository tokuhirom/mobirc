(function () {
    $.jQTouch({
        icon: 'jqtouch.png',
        statusBar: 'black-translucent',
        preloadImages: [
            '/static/jqtouch/themes/jqt/img/chevron.png',
            '/static/jqtouch/themes/jqt/img/back_button_clicked.png',
            '/static/jqtouch/themes/jqt/img/button_clicked.png'
        ]
    });

    function ts() { return (new Date()).getTime(); }
    Mobirc = {
        "bind" : function (selector, callback) {
            $(selector).bind("click", callback);
            $(selector).bind("tap",   callback);
        },
        "updateChannelList": function () {
            $('#contents').hide();
            $('#menu').load(
                docroot + 'iphone2/menu?t=' + ts(),
                '',
                function () {
                    Mobirc.bind('#menu .channel a', function () {
                        var elem = $(this);
                        Mobirc.loadContent(elem.text());
                        return false;
                    });
                    Mobirc.bind('#RefreshMenu', function() {
                        Mobirc.updateChannelList();
                    });
                    Mobirc.bind('#ClearAllUnread', function() {
                        $.post(
                            '/iphone2/clear_all_unread',
                            '',
                            function () {
                                Mobirc.updateChannelList();
                            }
                        );
                    });
                }
            );
        },
        "loadContent": function (channel) {
            $('#contents').load(
                docroot + 'iphone2/channel?channel=' + encodeURIComponent(channel) + '&t=' + ts(),
                '',
                function() {
                    $('#menu').html('');
                    $('#contents').show();
                    $('#input').ajaxForm(function () {
                        Mobirc.loadContent(channel);
                    });
                    Mobirc.bind('#goMenuButton', function() {
                        Mobirc.updateChannelList();
                        return false;
                    });
                    Mobirc.bind('#showChannelList', function() {
                        Mobirc.updateChannelList();
                        return false;
                    });
                }
            );
        },
        "initialize": function () {
            Mobirc.updateChannelList();
        }
    };
    $(function () {
        Mobirc.initialize();
    });
})();
