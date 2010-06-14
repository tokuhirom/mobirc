function ts() { return (new Date()).getTime(); }

var load_url;

function contents_load(url) {
    var joinner = (url.indexOf('?') == -1) ? '?' : '&';
    $('#contents').load(url+joinner+'time='+ts());
    load_url = url;
    $('#msg').focus();
}

function send_message() {
    $.post(load_url, {"msg":($('#msg').get())[0].value}, function (html) {
        setTimeout( function () { if (load_url) { contents_load(load_url) } }, 1*1000 );

        $('#contents br:last').focus();

        $('#msg').val('');
        $('#msg').focus();
    });
}

function load_menu () {
    $('#ChannelContainer').load(
        docroot + 'ajax/menu?time=' + ts(),
        '',
        function () {
            $('#ChannelContainer .channel a').click(function () {
                var channel_name = $(this).text();
                contents_load(docroot + 'ajax/channel?channel=' + encodeURIComponent($(this).text()), $(this).text());
                $.getJSON(docroot + 'api/members', {"channel": channel_name}, function (json) {
                    var container = $('#NickContainer');
                    container.empty();
                    for (var i=0; i<json.length; i++) {
                        container.append(
                            $(document.createElement('span')).text(json[i])
                        ).append(document.createElement('br'));
                    }
                });
                $(this).parent().removeClass('unread');
                return false;
            });

            var keyword_cb = function () {
                contents_load(docroot + 'ajax/keyword')
                $(this).parent().remove();
            };
            $('#ChannelContainer .keyword_recent_notice a').click(keyword_cb).keypress(keyword_cb);
        }
    );
}

// onload
$(function () {
    $('#msg').focus();

    (function () {
        load_menu();
        setInterval(load_menu, 4*1000);
    })();

    // $('#menu').resizable();

    setInterval(function(){ if(load_url){ contents_load(load_url); } }, 5*1000);
});

