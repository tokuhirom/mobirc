(function () {
    function ts() { return (new Date()).getTime(); }
    Mobirc = {
        showLoading: function () {
            $('#loading').show();
        },
        hideLoading: function () {
            $('#loading').hide();
        },
        "bind" : function (selector, callback) {
            $(selector).bind("click", callback);
            $(selector).bind("tap",   callback);
        },
        "updateChannelList": function () {
            $('#contents').hide();
            Mobirc.showLoading();
            $('#menu').load(
                docroot + 'iphone2/menu?t=' + ts(),
                '',
                function () {
                    Mobirc.bind('#menu .channel a', function () {
                        var elem = $(this);
                        elem.addClass('active');
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

                    Mobirc.hideLoading();
                }
            );
        },
        "loadContent": function (channel) {
            Mobirc.showLoading();
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

                    Mobirc.hideLoading();
                }
            );
        },
        showPage: function (id) { // id includes header '#'
            $('body > div').hide();
            $(id).show();

            Mobirc.dispatch(id);
        },
        initialize: function () {
            var page = '#menu';
            if (location.hash.match(/^#[a-z0-9_-]+$/)) {
                page = location.hash;
            }
            Mobirc.showPage(page);

            $('a').live('click', function () {
                var href = $(this).attr('href');
                Mobirc.showPage(href);
                location.href=href;
                return false;
            });
        },
        dispatch: function (id) {
            var code = Mobirc.dispatchMap[id.replace(/^#/, '')];
            if (code) {
                code();
            }
        },
        dispatchMap: {
            menu: function () {
                Mobirc.updateChannelList();
            }
        }
    };
    $(function () {
        Mobirc.initialize();
    });
})();
