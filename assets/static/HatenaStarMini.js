Deferred.Waiting = function () { this.waiting = [] };
Deferred.Waiting.prototype = {
    isReady : false,
    ready : function (value) {
        this.value = value;
        while (this.waiting.length) {
            this.waiting.shift().call(value);
        }
        this.isReady = true;
    },
    required : function (fun) {
        var self = this;
        var ret = new Deferred();
        if (typeof(this.value) == "undefined") {
            this.waiting.push(ret);
        } else {
            Deferred.next(function () { ret.call(self.value) });
        }
        return ret;
    }
};

Ten.Deferred = Deferred;

$E = createElementFromString;


function http (opts) {
    var d = Deferred();
    var req = Ten.XHR.getXMLHttpRequest();
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
        Global[cbname] = undefined;
        document.body.removeChild(script);
        d.call(data);
    };
    return d;
};

HatenaStarMini = {
    GET_URL_LENGTH_MAX : 2083,
    // GET_URL_LENGTH_MAX : 255,
    ENABLED     : (document.cookie.indexOf("faststar=y") != -1) && (!Ten.Browser.isIE || Ten.Browser.version > 7.0),
    RKS         : new Ten.Deferred.Waiting(),
    loaderQueue : [],
    preload     : 0,
    method      : (function () {
        var B = Ten.Browser;
        var v = B.version.valueOf();
        var isSupportedCSXHR = (B.isFirefox && v >= 3.5) ||
        //                     (!!window.XDomainRequest) ||
                               (B.isSafari  && v >= 4.0) ||
                               (B.isChrome  && v >= 2.0);
        if (isSupportedCSXHR) return "CSXHR";
        return "JSONP";
    })(),

    load : function (uri) {
        var ret = Ten.Deferred();
        var loaderQueue = this.loaderQueue;
        loaderQueue.push({ uri: uri, deferred: ret });

        if (!arguments.callee.called) {
            arguments.callee.called = true;
            new Ten.Observer(window, 'DOMContentLoaded', function () {
                if (HatenaStarMini.loaderQueue.length) HatenaStarMini.exhaust();
            });
            new Ten.Observer(window, 'onload', function () {
                if (HatenaStarMini.loaderQueue.length) HatenaStarMini.exhaust();
            });
            wait(0.1).next(function () {
                log("timer load");
                return HatenaStarMini.exhaust();
            }).
            error(function (e) {
                log(e);
            });
        }

        var can_immediately = HatenaStarMini.method == "CSXHR" || (!Ten.Browser.isFirefox);
        if (can_immediately && !HatenaStarMini.exhaust.max && loaderQueue.length > (HatenaStarMini.exhaust.max || 10)) {
            log("immediately load");
            HatenaStarMini.exhaust();
        }
        return ret;
    },

    exhaust : function () {
        if (!HatenaStarMini.loaderQueue.length) return null;
        if (!arguments.callee.n) arguments.callee.n = 0;
        arguments.callee.n++;
        arguments.callee.max = 10 * Math.pow(2, arguments.callee.n - 1);
        log(
            "exhaust" + HatenaStarMini.method + 
            " [called:" + arguments.callee.n + "] " +
            "load:" + HatenaStarMini.loaderQueue.length + " / max:" + arguments.callee.max
        );

        HatenaStarMini["exhaust" + HatenaStarMini.method]().
        next(function (res) {
            var data      = res.data;
            var deferreds = res.deferreds;
            var entries   = data.entries;
            if (data.rks) HatenaStarMini.RKS.ready(data.rks);
            aloop(entries.length, function (i) {
                var ds = deferreds[entries[i].uri];
                for (var j = 0, dslen = ds.length; j < dslen; j++) {
                    ds[j].call(entries[i]);
                }
            });
        }).
        error(log);

        return next(arguments.callee);
    },

    exhaustCSXHR : function () {
        var ret = new Ten.Deferred();

        var baseRequestURL = Hatena.Star.BaseURL + "/entries.json?";
        var deferreds = {};
        var url = baseRequestURL;
        var i   = 0;
        while (HatenaStarMini.loaderQueue.length && i < HatenaStarMini.exhaust.max && url.length < HatenaStarMini.GET_URL_LENGTH_MAX) {
            i++;
            var q = HatenaStarMini.loaderQueue.shift();
            if (!q) break;
            if (!deferreds[q.uri]) {
                deferreds[q.uri] = [];
                url += "&uri=" + encodeURIComponent(q.uri);
            }
            deferreds[q.uri].push(q.deferred);
        }

        var xhr = window.XDomainRequest ? new XDomainRequest() : new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.withCredentials = true;
        xhr.onload = function () {
            var data = eval("("+xhr.responseText+")");
            ret.call({ data: data, deferreds: deferreds });
        };
        xhr.send();
        return ret;
    },

    exhaustJSONP : function () {
        var ret = new Ten.Deferred();

        var Global = (function () { return this })();
        var cbname;
        do {
            cbname = "callback" + String(Math.random()).slice(2);
        } while (typeof(Global[cbname]) != "undefined");

        var baseRequestURL = Hatena.Star.BaseURL + "/entries.json?";
        var deferreds = {};
        var url = baseRequestURL;
        var i   = 0;
        url += "callback=" + cbname;
        while (HatenaStarMini.loaderQueue.length && i < HatenaStarMini.exhaust.max && url.length < HatenaStarMini.GET_URL_LENGTH_MAX) {
            i++;
            var q = HatenaStarMini.loaderQueue.shift();
            if (!q) break;
            if (!deferreds[q.uri]) {
                deferreds[q.uri] = [];
                url += "&uri=" + encodeURIComponent(q.uri);
            }
            deferreds[q.uri].push(q.deferred);
        }

        if (!this._head) this._head = document.getElementsByTagName("head")[0];
        var head = this._head;

        var script;

        if (Ten.Browser.isOpera) {
            var img = document.createElement("img");
            img.onerror = function () {
                img.parentNode.removeChild(img);
                script     = document.createElement('script');
                script.type    = 'text/javascript';
                script.charset = 'utf-8';
                script.src     = url;
                head.appendChild(script);
            };
            img.src    = url;
            document.lastChild.appendChild(img);
        } else {
            script = document.createElement('script');
            script.type    = "text/javascript";
            script.charset = "utf-8";
            script.src     = url;
            head.appendChild(script);
        }

        Global[cbname] = function callback (data) {
            Global[cbname] = undefined;
            head.removeChild(script);
            ret.call({ data: data, deferreds: deferreds });
        };
        return ret;
    },

    localCache : {
        enable : !!window.localStorage,
        // スターの簡略化情報だけをキャッシュする
        set : function (uri, info) {
            if (!this.enable) return;
            var t = [];
            var stars = info.stars;
            if (!stars.length) return;
            for (var i = 0, len = stars.length; i < len; i++) {
                var star = stars[i];
                t.push(star.name || star)
            }
            try {
                localStorage["star:" + uri] = t.join(';');
            } catch (e) {
                localStorage.clear();
            }
        },
        get : function (uri) {
            if (!this.enable) return null;

            var t = localStorage["star:" + uri];
            if (!t) return null;
            t = t.split(';');
            var ret = { can_comment: 0, stars : [] };
            for (var i = 0, len = t.length; i < len; i++) {
                if (/^\d+$/.test(t[i])) {
                    ret.stars.push(+t[i]);
                } else {
                    ret.stars.push({ name: t[i], quote : "" });
                }
            }
            return ret;
        }
    },

    init : function (selname) { try {
        if (!HatenaStarMini.ENABLED) return;
        Hatena.Star.EntryLoader.loadEntries = function () {};

        var me = document.getElementsByTagName("script");
        var entryNode = me[me.length - 1].parentNode;
        var entry = new HatenaStarMini.Entry(selname, entryNode);

        var cache = HatenaStarMini.localCache.get(entry.uri);
        if (cache) {
            entry.setStars(cache);
        }

        HatenaStarMini.load(entry.uri).
        next(function (info) {
            entry.setStars(info);
            HatenaStarMini.localCache.set(entry.uri, info);
        }).
        error(function (e) {
            log(e);
        });

    } catch (e) { log(e) } },

    addStar : function (entry) {
        var tmpimg = entry.createStarElement({ name : "" }, "temp");
        entry.star_container.appendChild(tmpimg);

        log(["add star queued", entry]);
        return HatenaStarMini.RKS.required().next(function (rks) {
            var url = Hatena.Star.BaseURL + "star.add.json?"; 
            var query = [];
            var quote = "";
            with (entry) {
                query.push("uri="      + encodeURIComponent(uri));
                query.push("title="    + encodeURIComponent(title));
                query.push("quote="    + encodeURIComponent(quote));
                query.push("locaiton=" + encodeURIComponent(document.location.href));
                query.push("rks="      + encodeURIComponent(rks));
            }
            url += query.join("&");

            return http.jsonp(url).next(function (res) {
                if (res.errors) {
                    var pos = Ten.Geometry.getElementPosition(tmpimg);
                    pos.x -= 10;
                    pos.y += 25;

                    var scroll = Ten.Geometry.getScroll();
                    var scr = new Hatena.Star.AlertScreen();
                    var alert = res.errors[0];
                    scr.showAlert(alert, pos);

                    tmpimg.parentNode.removeChild(tmpimg);
                } else {
                    var s = entry.createStarElement(res, res.color);
                    tmpimg.parentNode.replaceChild(s, tmpimg);
                }
            });
        }).error(function (e) { log(["addStar Error:", e]); throw e });
    },

    bulkStars : function (stars) {
        var star_width  = 11;
        var stars_width = stars.length * star_width;

        var bulk_container = document.createElement("span");
        var style = bulk_container.style;
        style.background    = "url(http://s.hatena.ne.jp/images/star.gif)";
        style.display       = "inline-block";
        style.width         = stars_width + "px";
        style.height        = "10px";
        style.verticalAlign = "middle";

        var target = function (e) {
            var pos = Ten.Geometry.getElementPosition(bulk_container);
            var xx = e.mousePosition().x - pos.x;

            var index = Math.floor(xx / star_width);
            if (index >= stars.length) index = stars.length - 1;
            if (index < 0) index = 0;

            var star  = stars[index];
            return star;
        };

        return {
            container : bulk_container,
            target    : target
        };
    },

    showName : function (e, star) {
        if (!this.screen) this.screen = new Hatena.Star.NameScreen();
        var pos = e.mousePosition();
        pos.x += 10;
        pos.y += 25;
        // if (this.highlight) this.highlight.show();
        this.screen.showName(star.name, star.quote, pos, star.profile_icon);
        this.screen.container.style.zIndex = 4;
    },

    hideName : function () {
        if (!this.screen) return;
        // if (this.highlight) this.highlight.hide();
        this.screen.hide();
    },

    enable : function () {
        new Ten.Cookie().set("faststar", "y");
        location.reload();
    },

    disable : function () {
        new Ten.Cookie().set("faststar", "");
        location.reload();
    },

    toggle : function () {
        this[this.ENABLED ? "disable" : "enable"]();
    }
};

HatenaStarMini.User = new Ten.Class({
    base : [Hatena.User],
    initialize : function (name) {
        if (HatenaStarMini.User._cache[name]) {
            return HatenaStarMini.User._cache[name];
        } else {
            this.name = name;
            HatenaStarMini.User._cache[name] = this;
            return this;
        }
    },
    getProfileIcon : function(name,src) {
        if (!name) name = 'user';
        var img = document.createElement('img');
        if (src) {
            img.src = src;
        } else {
            var pre = name.match(/^[\w-]{2}/)[0];
            img.src = 'http://www.st-hatena.com/users/' + pre + '/' + name + '/profile_s.gif';
        }
        img.setAttribute('alt', name);
        img.setAttribute('title', name);
        img.setAttribute('width', '16px');
        img.setAttribute('height', '16px');
        img.className =  'profile-icon';
        img.setAttribute('style', 'margin: 0 3px; border: none; vertical-align: middle; width: 16px; height: 16px');
        return img;
    },
    _cache: {}
}, {
    userPage : function (add) {
        return '/' + this.name + '/' + (add || "");
    },

    locate : function (add) {
        location.href = this.userPage(add);
    },

    open : function (add) {
        window.open(this.userPage(add));
    }
});


HatenaStarMini.StarScreen = new Ten.Class({
    base: [Ten.SubWindow],
    style: {
        zIndex: "1",
        padding: '2px',
        textAlign: 'left',
        backgroundColor: '#000',
        width: '240px',
        border: "1px solid #000",
        opacity : "0.9"
    },
    containerStyle : {
        margin: "20px 10px 10px"
    },
    handleStyle: {
        position: 'absolute',
        top: '0px',
        left: '0px',
        width: '100%',
        height: '30px'
    }
}, {
    showStars: function (stars, pos) {
        var star_container = this.container;
        star_container.innerHTML = "";

        // count 付き star を展開
        for (var i = 0, len = stars.length; i < len; i++) {
            var star = stars[i];
            if (star.count) {
                star.count = +star.count;
                var args = new Array(2 + star.count - 1);
                args[0] = i;
                args[1] = 0;
                while (star.count--) args[star.count + 2] = star;
                log(args.length - 2);
                stars.splice.apply(stars, args); 
            };
        }

        var wsize = 20;
        var hsize = Math.ceil(stars.length / wsize);
        for (var y = 0; y < hsize; y++) (function () {
            var part = stars.slice(y * wsize, y * wsize + wsize);
            var bulkStars = HatenaStarMini.bulkStars(part);
            var container = bulkStars.container;
            var target    = bulkStars.target;
            star_container.appendChild(container);

            new Ten.Observer(container, "onmousemove", function (e) {
                var star  = target(e);
                HatenaStarMini.showName(e, star);
            });

            new Ten.Observer(container, "onmouseup", function (e) {
                var star  = target(e);
                if (e.event.which == 2 || (!e.event.which && e.event.button & 4)) {
                    new HatenaStarMini.User(star.name).open();
                } else {
                    new HatenaStarMini.User(star.name).locate();
                }
            });

            new Ten.Observer(container, "onmouseout", function (e) {
                HatenaStarMini.hideName();
            });
        })();

        var win = Ten.Geometry.getWindowSize();
        var scr = Ten.Geometry.getScroll();
        var w = parseInt(this.constructor.style.width) + 20;
        if (pos.x + w > scr.x + win.w) pos.x = win.w + scr.x - w;
        this.show(pos);
    }
});



HatenaStarMini.Pallet = new Ten.Class({
    base: [Ten.SubWindow],
    initialize : function () {
        new Ten.Observer(window, "onclick", this, "hide");
        return this.constructor.SUPER.apply(this, arguments);
    },
    style: {
        padding: '0px',
        textAlign: 'center',
        border: '0px'
    },
    containerStyle: {
        textAlign: 'left',
        margin: 0,
        padding: 0
    },
    handleStyle: null,
    showScreen: false,
    closeButton: null,
    draggable: false,
    SELECTED_COLOR_ELEMENT_ID: 'hatena-star-selected-color',
    PALLET_ELEMENT_ID: 'hatena-star-color-pallet'
},{
    selectColor : function (entry) {
        if (this.deferred) this.deferred.cancel();
        this.deferred = new Ten.Deferred();
        this.deferred.entry = entry;
        this.showPallet();
        return this.deferred;
    },

    showPallet: function () {
        this.hide();
        this.container.innerHTML = '<iframe id="' + HatenaStarMini.Pallet.PALLET_ELEMENT_ID + '" src="' + 
            Hatena.Star.BaseURL + 'colorpalette?uri=' + encodeURIComponent(this.deferred.entry.uri) +
            '" frameborder="0" border="0" scrolling="no" style="width:16px;height:51px;overflow:hidden;"/>';
        this.pallet = this.container.childNodes[0];
        this.isNowLoading = true;
        this.palletStatus = 0;
        new Ten.Observer(this.pallet, 'onload', this, 'observerSelectColor');
    },

    observerSelectColor : function (e) {
        var pos = Ten.Geometry.getElementPosition(this.deferred.entry.star_add_button);
        if (Ten.Browser.isFirefox || Ten.Browser.isOpera) {
            pos.y += 15;
            pos.x += 2;
        } else {
            pos.y += 13;
        }

        switch (this.palletStatus++) {
            case 0: // pallet loaded
                log("loaded");
                this.show(pos);
                break;
            case 1: // pallet color selected
                log("selected");
                this.hide();
                this.container.innerHTML = "";
                this.deferred.call();
                break;
        }
    }
});


/*
 * span.hatena-star-comment-container
 * span.hatena-star-star-container
 *   img.hatena-star-add-button
 *   a
 *   a
 *   a...
 */
HatenaStarMini.Entry = new Ten.Class({
    initialize : function (selector, entryNode) {
        var sel        = Hatena.Star.SiteConfig.entryNodes[selector];

        this.selector  = selector;
        this.entryNode = entryNode;
        this.container = Ten.querySelector(sel.container, entryNode);
        if (!this.container) return;
        this.uri       = Ten.querySelector(sel.uri, entryNode).href;
        this.uri       = this.uri.replace(RegExp("http://local.hatelabo.jp(:\\d+)?/"), "http://copie.hatelabo.jp/");
        this.uri       = this.uri.replace(RegExp("http://copy(.+).hatena.ne.jp/"), "http://copie.hatelabo.jp/");
        this.title     = Hatena.Star.EntryLoader.scrapeTitle(Ten.querySelector(sel.title, entryNode));

        this.initStarContainer();
    },

    star_container : (function () {
        var star_container, star_add_button;
        star_container = document.createElement("span");
        star_container.className = "hatena-star-star-container";
        star_add_button = document.createElement("img");
        star_add_button.src = 'http://s.hatena.ne.jp/images/add.gif';
        star_add_button.alt = "";
        star_add_button.className = "hatena-star-add-button";
        star_add_button.setAttribute('style', "border: medium none ; margin: 0pt 3px; padding: 0pt; cursor: pointer; vertical-align: middle;");
        star_container.appendChild(star_add_button);
        return star_container;
    })()
}, {
    initStarContainer : function () {
        var star_container  = HatenaStarMini.Entry.star_container.cloneNode(true);
        this.star_add_button = star_container.getElementsByTagName("img")[0]; 
        if (this.star_container) {
            this.container.replaceChild(star_container, this.star_container);
        } else {
            this.container.appendChild(star_container);
        }
        this.star_container = star_container;

        var selectTimer = Ten.Deferred();
        var self = this;
        new Ten.Observer(this.star_add_button, "onclick", this, "addStar");
        new Ten.Observer(this.star_add_button, "onmouseover", function () {
            selectTimer.cancel();
            selectTimer = wait(1).next(function () {
                self.selectColor();  
            });
        });
        new Ten.Observer(this.star_add_button, "onmouseout", function () {
            selectTimer.cancel();
        });
    },

    addStar : function () {
        HatenaStarMini.addStar(this);
    },

    setStars : function (info) {
        var self = this;
        if (this.info) this.initStarContainer();
        this.info = info;

        var star_container = this.star_container;
        var all_stars      = info.colored_stars ? info.colored_stars.concat([ info ])
                                                : [ info ]; 

//        var temp           = document.createTextNode("");
//        this.container.replaceChild(temp, star_container);

        for (var c = 0, alen = all_stars.length; c < alen; c++) {
            var stars = all_stars[c].stars;
            var color = all_stars[c].color;
            for (var i = 0, len = stars.length; i < len; i++) {
                var star = stars[i];
                if (typeof(star) == "number") {
                    var inner_star = document.createElement("span");
                    inner_star.className = "hatena-star-inner-count";
                    inner_star.appendChild(document.createTextNode(star));
                    inner_star.setAttribute("style", 'margin: 0pt 2px; font-weight: bold; font-size: 80%; font-family: "arial",sans-serif; color: rgb(244, 177, 40); cursor: pointer;');
                    star_container.appendChild(inner_star);

                    new Ten.Observer(inner_star, "onmouseup", function (e) {
                        log(e);
                        http.jsonp(Hatena.Star.BaseURL + "entry.json", { uri : info.uri }).
                        next(function (data) {
                            var info = data.entries[0];
                            var stars = info.stars;

                            var pos = Ten.Geometry.getElementPosition(inner_star);
                            pos.x -= 10;
                            pos.y += 25;
                            var scroll = Ten.Geometry.getScroll();
                            var scr = new HatenaStarMini.StarScreen();
                            scr.showStars(stars, pos);
                        }).
                        error(function (e) {
                            log(e)
                        })
                    });
                } else {
                    var elem = this.createStarElement(star, color);
                    star_container.appendChild(elem);
                }
            }
        }

//        this.container.replaceChild(star_container, temp);
        new Ten.Observer(this.star_container, "onmousemove", this, 'showName');
        new Ten.Observer(this.star_container, "onmouseout", HatenaStarMini, 'hideName');
    },

    createStarElement : function (star, color) {
        var a = document.createElement("a");
        a.href = "/" + star.name + "/";
        a.className = "hatena-star-star " + (color || "");
        a._star = star;
        return a;
    },

    showName : function (e) {
        var star = e.target._star;
        if (star) {
            HatenaStarMini.showName(e, star);
        }
    },

    selectColor : function (e) {
        log([ "selecting", this.uri ]);
        var self = this;
        new HatenaStarMini.Pallet().selectColor(this).next(function () {
            self.addStar();
        });
    }
});

if (HatenaStarMini.ENABLED) {
    var style = document.createElement("style");
    style.type = "text/css";
    style.appendChild(document.createTextNode(".banners .banner .info { visibility: visible; }"));
    document.getElementsByTagName("head")[0].appendChild(style);
}
//
//Ten.DOM.addEventListener("DOMContentLoaded", function () {
//    var sels = [];
//    var selectors = Hatena.Star.SiteConfig.entryNodes;
//    for (var selector in selectors) if (selectors.hasOwnProperty(selector)) {
//        sels.push(selector);
//    }
//
//    loop(sels.length, function (n) {
//        var selector = sels[n];
//
//        var entryNodes = Ten.querySelectorAll(selector);
//        if (!entryNodes.length) return;
//
//        for (var i = 0, len = entryNodes.length; i < len; i++) (function (entryNode) {
//            var entry = new HatenaStarMini.Entry(selector, entryNode);
//
//            if (entry.uri)
//                HatenaStarMini.load(entry.uri).
//                next(function (info) {
//                    entry.setStars(info);
//                }).
//                error(function (e) {
//                    log(e);
//                });
//        })(entryNodes[i]);
//    }).
//    error(function (e) {
//        log(e);
//    });
//});



