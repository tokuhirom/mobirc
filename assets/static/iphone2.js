// http://d.hatena.ne.jp/amachang/20100917/1284700700
function assert(condition, opt_message) {
    if (!condition) {

        if (window.console) {

            console.log('Assertion Failure');
            if (opt_message) console.log('Message: ' + opt_message);

            if (console.trace) console.trace();
            if (Error().stack) console.log(Error().stack);
        }

        debugger;
    }
}

(function () {
    $.ajaxSetup({cache: false});

    Mobirc = {
        latestPost: '',
        bind: function (selector, callback) {
            $(selector).bind("click", callback);
            $(selector).bind("tap",   callback);
        },
        initialize: function () {
            $('#postForm').submit(function () {
                $('#MessageBox').disable();
                return true;
            });
            Mobirc.bind('#RefreshMenu', function() {
                location.replace(location.href);
            });
            Mobirc.bind('#ClearAllUnread', function() {
                $.post(
                    docroot + 'api/clear_all_unread',
                    '',
                    function () {
                        location.replace(location.href);
                    }
                );
            });
        }
    };
    $(function () {
        Mobirc.initialize();
    });
})();
