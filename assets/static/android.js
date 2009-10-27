function http (opts) {
    var d = Deferred();
    var req = new XMLHttpRequest();
    req.open(opts.method, opts.url, true);
    if (opts.headers) {
        for (var k in opts.headers) if (opts.headers.hasOwnProperty(k)) {
            req.setRequestHeader(k, opts.headers[k]);
        }
    }
    req.onreadystatechange = function () {
        if (req.readyState == 4) d.call(req);
    };
    req.send(opts.data || null);
    d.xhr = req;
    return d;
}
http.get   = function (url)       { return http({method:"get",  url:url}) };
http.post  = function (url, data) { return http({method:"post", url:url, data:data, headers:{"Content-Type":"application/x-www-form-urlencoded"}}) };
http.jsonp = function (url, params) {
    if (!params) params = {};

    var Global = (function () { return this })();
    var d = Deferred();
    var cbname = params["callback"];
    if (!cbname) do {
        cbname = "callback" + String(Math.random()).slice(2);
    } while (typeof(Global[cbname]) != "undefined");

    params["callback"] = cbname;

    url += (url.indexOf("?") == -1) ? "?" : "&";

    for (var name in params) if (params.hasOwnProperty(name)) {
        url = url + encodeURIComponent(name) + "=" + encodeURIComponent(params[name]) + "&";
    }

    var script = document.createElement('script');
    script.type    = "text/javascript";
    script.charset = "utf-8";
    script.src     = url;
    document.body.appendChild(script);

    Global[cbname] = function callback (data) {
        delete Global[cbname];
        document.body.removeChild(script);
        d.call(data);
    };
    return d;
};



function createElementFromString (str, opts) {
    if (!opts) opts = { data: {} };
    if (!opts.data) opts.data = { };

    var t, cur = opts.parent || document.createDocumentFragment(), root, stack = [cur];
    while (str.length) {
        if (str.indexOf("<") == 0) {
            if ((t = str.match(/^\s*<(\/?[^\s>\/]+)([^>]+?)?(\/)?>/))) {
                var tag = t[1], attrs = t[2], isempty = !!t[3];
                if (tag.indexOf("/") == -1) {
                    child = document.createElement(tag);
                    if (attrs) attrs.replace(/([a-z]+)=(?:'([^']+)'|"([^"]+)")/gi,
                        function (m, name, v1, v2) {
                            var v = text(v1 || v2);
                            if (name == "class") root && (root[v] = child), child.className = v;
                            child.setAttribute(name, v);
                        }
                    );
                    cur.appendChild(root ? child : (root = child));
                    if (!isempty) {
                        stack.push(cur);
                        cur = child;
                    }
                } else cur = stack.pop();
            } else throw("Parse Error: " + str);
        } else {
            if ((t = str.match(/^([^<]+)/))) cur.appendChild(document.createTextNode(text(t[0])));
        }
        str = str.substring(t[0].length);
    }

    function text (str) {
        return str
            .replace(/&(#(x)?)?([^;]+);/g, function (_, isNumRef, isHex, ref) {
                return isNumRef ? String.fromCharCode(parseInt(ref, isHex ? 16 : 10)):
                                  {"lt":"<","gt":"<","amp":"&"}[ref];
            })
            .replace(/#\{([^}]+)\}/g, function (_, name) {
                return (typeof(opts.data[name]) == "undefined") ? _ : opts.data[name];
            });
    }

    return root;
}


function getCurrentLocation (callback) {
    var geo = navigator.geolocation || google.gears.factory.create('beta.geolocation');
    var dialog = createElementFromString(
        ['<div class="overlay">',
            '<div class="content">',
                '<span class="message">GPS Fixing...</span><input type="button" value="Cancel" class="cancel"/>',
             '</div>',
         '</div>'].join(''), {
            parent: document.body
        }
    );

    dialog.setAttribute('style', 'color: #fff; background: #000; opacity: 0.9; position: absolute; top: 0; left: 0;');
    dialog.style.height = (document.documentElement.scrollHeight) + 'px';
    dialog.style.width  = (document.documentElement.scrollWidth)  + 'px';

    dialog.content.setAttribute('style', 'position: absolute; text-align: center; vertical-align: 50%; width: 100%;');
    dialog.content.style.lineHeight = (window.innerHeight) + 'px';
    dialog.content.style.top        = (window.pageYOffset) + 'px';

    document.body.style.overflow = 'hidden';

    var id = geo.watchPosition(
        function (pos) {
            geo.clearWatch(id);
            callback(pos);
            dialog.parentNode.removeChild(dialog);
        },
        function (e) {
        },
        {
            enableHighAccuracy: true,
            maximumAge: 0,
            gearsLocationProviderUrls: []
        }
    );

    dialog.cancel.addEventListener('click', function (e) {
        document.body.style.overflow = 'visible';
        geo.clearWatch(id);
        dialog.parentNode.removeChild(dialog);
    }, false);

    dialog.cancel.focus();
}


new function PostOperations () {
    var define = {
        Post : function (form) {
            form.submit();
        },
        Location : function (form, input) {
            getCurrentLocation(function (pos) {
                var lat = pos.coords.latitude;
                var lon = pos.coords.longitude;
                var q   = lat + ',+' + lon + (
//                    input.value ?
//                    '+' + '(' + encodeURIComponent(input.value) + ')':
                    ''
                );
                var uri = 'http://maps.google.co.jp/maps?q=' + q + '&iwloc=A&hl=ja';
                input.value += " " + uri;
                form.submit();
            });
        }
    };

    var form = document.getElementById("input");
    if (form) {
        var input = form.querySelector("input[name=msg]");
        var select = document.querySelector("select.post");
        select.addEventListener("change", function (e) {
            var fun = define[select.value];
            try {
                if (fun) fun(form, input);
            } catch (e) { alert(e) }
            select.selectedIndex = 0;
        }, false);
    }
};

new function LineOperation () {
    var form = document.getElementById("input");
    if (form) {
        var input = form.querySelector("input[name=msg]");

        form.addEventListener("submit", function (e) {
            e.preventDefault();

            input.disabled = true;
            input.style.background = "#ccc";

            var img = document.createElement("img");
            img.className = "loading";
            img.src = docroot + "static/loading.gif";

            form.appendChild(img);

            $.post(form.action, {
                msg : input.value
            }, function (data) {
                input.value = "";
                location.replace(location.href);
            });
        }, false);

        var selects = document.querySelectorAll("select.operations");
        for (var i = 0, len = selects.length; i < len; i++) {
            with ({select : selects[i]}) select.addEventListener("change", function (e) {
                input.value = select.value;
                input.focus();
                scrollTo(0, 0);
                form.submit();
            }, false);
        }
    }
};

new function Pager () {
    var loading = false;

    var content  = document.getElementById('content');
    var nextLink = document.querySelector("a[rel='next']");

    window.addEventListener('scroll', function (e) {
        if (loading) return;

        var height = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
        var remain = height - window.innerHeight - window.scrollY;
        if (remain < 100 + window.innerHeight) {
            loading = true;
            if (nextLink) {
                nextLink.innerHTML = "loading...";
                http.get(nextLink.href).next(function (xhr) {
                    var tmp = document.createElement('div');
                    tmp.innerHTML = xhr.responseText;
                    var page = tmp.querySelectorAll("#content > *");
                    if (page.length) {
                        for (var i = 0, len = page.length; i < len; i++) {
                            content.appendChild(page[i]);    
                        }
                        nextLink.href = tmp.querySelector("a[rel='next']").href;
                        loading = false;
                    } else {
                        nextLink.parentNode.removeChild(nextLink);
                    }
                });
            } else {
                window.removeEventListener('scroll', arguments.callee, false);
            }
        }
    }, false);
};


new function HistoryControl () {
    var more = document.querySelectorAll('div.more a');
    for (var i = 0, len = more.length; i < len; i++) {
        var href = more[i].href;
        more[i].href = 'javascript:location.replace("'+href+'")';
    }
};


