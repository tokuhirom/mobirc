/*
 * HatenaStar.js をスマートフォン向けに最小限実装したもの
 * オフィシャルな実装から以下の機能を削っている
 *
 *  * スターコメント機能
 *  * カラースター機能
 *  * 引用スター機能
 *  * クロスブラウザ対応
 *
 */

Deferred.define();

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

function aloop (n, f) {
    var i   = 0;
    var end = new Object;
    var ret = null;
    return Deferred.next(function () {
        var t = (new Date()).getTime();
        try {
            do {
                ret = f(i)
                i++;
                if (i >= n) throw end;
            } while ((new Date()).getTime() - t < 20);
            return Deferred.call(arguments.callee);
        } catch (e) {
            if (e == end) {
                return ret;
            } else {
                throw e;
            }
        }
    });
}

function jsonp (url, params) {
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


Hatena = {};
Hatena.Star = {};
Hatena.Star.BaseURL = 'http://s.hatena.ne.jp';

HatenaStar4Android = {
    ENABLED     : true,
    loaderQueue : [],
    RKS         : new Deferred.Waiting(),
    GET_URL_LENGTH_MAX : 2083,

    load : function (uri) {
        var ret = new Deferred();
        var loaderQueue = this.loaderQueue;
        loaderQueue.push({ uri: uri, deferred: ret });

        if (!arguments.callee.called) {
            arguments.callee.called = true;
            window.addEventListener('DOMContentLoaded', function () {
                if (HatenaStar4Android.loaderQueue.length) HatenaStar4Android.exhaust();
            }, true);
            window.addEventListener('load', function () {
                if (HatenaStar4Android.loaderQueue.length) HatenaStar4Android.exhaust();
            }, false);

            wait(0.1).next(function () {
                log("timer load");
                return HatenaStar4Android.exhaust();
            }).
            error(function (e) {
                log(e);
            });
        }

        return ret;
    },

    exhaust : function () {
        if (!HatenaStar4Android.loaderQueue.length) return null;
        if (!arguments.callee.n) arguments.callee.n = 0;
        if (arguments.callee.n > 5) return null;
        arguments.callee.n++;
        arguments.callee.max = 10 * Math.pow(2, arguments.callee.n - 1);

        HatenaStar4Android.exhaustJSONP().
        next(function (res) {
            var data      = res.data;
            var deferreds = res.deferreds;
            var entries   = data.entries || [];
            if (data.rks) HatenaStar4Android.RKS.ready(data.rks);
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

    exhaustJSONP : function () {
        var ret = new Deferred();

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
        while (HatenaStar4Android.loaderQueue.length && i < HatenaStar4Android.exhaust.max && url.length < HatenaStar4Android.GET_URL_LENGTH_MAX) {
            i++;
            var q = HatenaStar4Android.loaderQueue.shift();
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
        script = document.createElement('script');
        script.type    = "text/javascript";
        script.charset = "utf-8";
        script.src     = url;
        head.appendChild(script);

        Global[cbname] = function callback (data) {
            Global[cbname] = undefined;
            head.removeChild(script);
            ret.call({ data: data, deferreds: deferreds });
        };
        return ret;
    },

    init : function (selname) { try {
        if (!HatenaStar4Android.ENABLED) return;
        Hatena.Star.EntryLoader.loadEntries = function () {};

        var me = document.getElementsByTagName("script");
        var entryNode = me[me.length - 1].parentNode;
        var entry = new HatenaStar4Android.Entry(selname, entryNode);

//        var cache = HatenaStar4Android.localCache.get(entry.uri);
//        if (cache) {
//            entry.setStars(cache);
//        }

        HatenaStar4Android.load(entry.uri).
        next(function (info) {
            entry.setStars(info);
//            HatenaStar4Android.localCache.set(entry.uri, info);
        }).
        error(function (e) {
            log(e);
        });

    } catch (e) { log(e) } },

    addStar : function (entry) {
        var tmpimg = entry.createStarElement({ name : "" }, "temp");
        entry.star_container.appendChild(tmpimg);

        return HatenaStar4Android.RKS.required().next(function (rks) {
            var url = Hatena.Star.BaseURL + "/star.add.json?"; 
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

            return jsonp(url).next(function (res) {
                if (res.errors) {
                    if (confirm("ログインしてください")) {
                        window.open("https://www.hatena.ne.jp/login");
                    }

                    tmpimg.parentNode.removeChild(tmpimg);
                } else {
                    var s = entry.createStarElement(res, res.color);
                    tmpimg.parentNode.replaceChild(s, tmpimg);
                }
            });
        }).error(function (e) { log(["addStar Error:", e]); throw e });
    },

    showName : function (e, star) {
        if (!this.screen) this.screen = new HatenaStar4Android.NameScreen();

        var pos = {
            x : e.clientX + window.pageXOffset,
            y : e.clientY + window.pageYOffset
        };

        pos.x += 10;
        pos.y += 25;

        this.screen.showName(star.name, star.quote, pos, HatenaStar4Android.profileIcon(star.name));
        this.screen.container.style.zIndex = 4;
    },

    hideName : function () {
        if (!this.screen) return;
        this.screen.hide();
    },

    profileIcon : function (name) {
        return 'http://www.st-hatena.com/users/' + name.substring(0, 2) + '/' + name + '/profile_s.gif';
    }
};

/*
 * span.hatena-star-comment-container
 * span.hatena-star-star-container
 *   img.hatena-star-add-button
 *   a
 *   a
 *   a...
 */
HatenaStar4Android.Entry = function (selector, entryNode) {
    var sel        = Hatena.Star.SiteConfig.entryNodes[selector];
    this.selector  = selector;
    this.entryNode = entryNode;
    this.container = entryNode.querySelector(sel.container);
    if (!this.container) return;
    this.uri       = (entryNode.querySelector(sel.uri) || {}).href;
    this.title     = "";
    if (!this.uri) return;

    this.initStarContainer();
};
HatenaStar4Android.Entry.prototype = {
    initStarContainer : function () {
        var star_container  = HatenaStar4Android.Entry.star_container.cloneNode(true);
        this.star_add_button = star_container.getElementsByTagName("img")[0]; 
        if (this.star_container) {
            this.container.replaceChild(star_container, this.star_container);
        } else {
            this.container.appendChild(star_container);
        }
        this.star_container = star_container;

        var self = this;
        this.star_add_button.addEventListener("click", function () {
            self.addStar();
        }, false);
    },

    addStar : function () {
        HatenaStar4Android.addStar(this);
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

                    inner_star.addEventListener("mouseup", function (e) {
                        jsonp(Hatena.Star.BaseURL + "/entry.json", { uri : info.uri }).
                        next(function (data) {
                            var info = data.entries[0];
                            var stars = info.stars;
                            // TODO: 展開：いいUIが思いつかない
                        }).
                        error(function (e) {
                            log(e)
                        })
                    }, false);
                } else {
                    var elem = this.createStarElement(star, color);
                    star_container.appendChild(elem);
                }
            }
        }

//        this.container.replaceChild(star_container, temp);
        this.star_container.addEventListener("mousemove", function (e) {
            self.showName(e);
        }, false);

        this.star_container.addEventListener("mouseout", function () {
            HatenaStar4Android.hideName()
        }, false);
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
            HatenaStar4Android.showName(e, star);
        }
    }
};

HatenaStar4Android.Entry.star_container = (function () {
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
})();

HatenaStar4Android.NameScreen = function () {
    this.container = document.createElement('div');
    this.img       = document.createElement('img');
    this.name      = document.createElement('span');
    this.quote     = document.createElement('div');

    this.container.appendChild(this.img);
    this.container.appendChild(this.name);
    this.container.appendChild(this.quote);

    this.img.setAttribute('style', 'width: 16px; height: 16px; vertical-align: middle; margin: 0 5px 0 0');
    this.container.setAttribute('style', 'position: absolute; border: 1px solid #ccc; padding: 2px; font-size: 90%; background: #fff; color: #000;');

    document.body.appendChild(this.container);
};
HatenaStar4Android.NameScreen.prototype = {
    showName: function (name, quote, pos, src) {
        this.name.innerText  = name;
        this.quote.innerText = quote;
        this.img.src         = src;

        var s     = this.container.style;
        s.display = "block";
        s.top     = pos.y + "px";
        s.left    = pos.x + "px";
    },

    hide : function () {
        this.container.style.display = "none";
    }
};


window.addEventListener("DOMContentLoaded", function () {
    try {
    var entryNodesConfigs = Hatena.Star.SiteConfig.entryNodes;
    for (var entryNodeSelector in entryNodesConfigs) if (entryNodesConfigs.hasOwnProperty(entryNodeSelector)) {
        var selectors = entryNodesConfigs[entryNodeSelector];

        var entryNodes = document.querySelectorAll(entryNodeSelector);    
        var entries    = [];
        for (var i = 0, len = entryNodes.length; i < len; i++) (function (entryNode) {
            var entry = new HatenaStar4Android.Entry(entryNodeSelector, entryNode);

            if (entry.uri)
                HatenaStar4Android.load(entry.uri).
                next(function (info) {
                    entry.setStars(info);
                }).
                error(function (e) {
                    log(e);
                });
        })(entryNodes[i]);
    }
    } catch (e) { alert(e) }
    
}, false);


function log (m) { console.log(m) }
