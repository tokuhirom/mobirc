function ts() { return (new Date()).getTime(); }

var load_url;

function contents_load(url) {
    var joinner = (url.indexOf('?') == -1) ? '?' : '&';
    $.getJSON(
        url + joinner + 'time='+ts(),
        function (res) {
            $('#contents').html( res.messages.join("<br />") );
            $('title').html( res.channel_name + " - mobirc" );
        }
    );
    load_url = url;
//    $('#msg').focus();
}

function send_message() {
    $.post(load_url, {"msg":($('#msg').get())[0].value}, function (html) {
        setTimeout( function () { if (load_url) { contents_load(load_url) } }, 1*1000 );

//        $('#contents br:last').focus();

        $('#msg').val('');
        $('#msg').focus();
    });
}

function load_menu () {
    $('#menu').load(
        docroot + 'iphone/menu?time=' + ts(),
        '',
        function () {
            $('#menu .channel a').click(function () {
                contents_load(docroot + 'iphone/channel?channel=' + encodeURIComponent($(this).text()), $(this).text());
                $(this).parent().removeClass('unread');
                return false;
            });

            var keyword_cb = function () {
                contents_load(docroot + 'iphone/keyword')
                $(this).parent().remove();
            };
            $('#menu .keyword_recent_notice a').click(keyword_cb).keypress(keyword_cb);
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

    setInterval(function(){ if(load_url){ contents_load(load_url); } }, 5*1000);
});

