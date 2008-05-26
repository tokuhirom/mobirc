function ts() { return (new Date()).getTime(); }

var load_url;

function contents_load(url) {
    $('#contents').load(url+'?time='+ts());
    load_url = url;
    $('#msg').focus();
}

function send_message() {
    $.post(load_url, {"msg":($('#msg').get())[0].value}, function (html) {
        $('#contents').html(html);
        setTimeout( function () { if (load_url) { contents_load(load_url) } }, 1*1000 );

        $('#contents br:last').focus();

        $('#msg').val('');
        $('#msg').focus();
    });
}

function load_menu () {
    $('#menu').load(
        docroot + 'pc/menu?time=' + ts(),
        '',
        function () {
            $('#menu .channel a').click(function () {
                contents_load(docroot + 'channels/' + encodeURIComponent($(this).text()), $(this).text());
                $(this).parent().removeClass('unread');
            });

            var keyword_cb = function () {
                contents_load(docroot + 'pc/keyword')
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

