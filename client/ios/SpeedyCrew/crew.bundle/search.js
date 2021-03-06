var rootSectors = [
    { tag:"construction", name:"Construction", sectors:[] },
    { tag:"hospitality", name:"Hospitality", sectors:[
          { tag:"chef-meat", name:"Chef de Partie (meat)", sectors:[] },
          { tag:"chef-fish", name:"Chef de Partie (fish)", sectors:[] },
          { tag:"chef-pasta", name:"Chef de Partie (pasta)", sectors:[] },
          { tag:"chef-salad", name:"Chef de Partie (salad)", sectors:[] },
          { tag:"chef-pastry", name:"Chef de Partie (pastry)", sectors:[] },
          { tag:"chef-commis", name:"Chef de Partie (commis)", sectors:[] },
          { tag:"waiter", name:"Waiter", sectors:[] },
          { tag:"sommelier", name:"Sommelier", sectors:[] },
          { tag:"barman", name:"Barman", sectors:[] },
          { tag:"kitchen-porter", name:"Kitchen Porter", sectors:[] },
          { tag:"receptionist", name:"Receptionist", sectors:[] }
          ]
    },
    { tag:"cleaner", name:"Cleaner", sectors:[] }
];

function searchCall(fun, arg) {
    var iframe = document.createElement("iframe");
    iframe.setAttribute("src", "jscall://" + fun + "/" + arg);
    document.documentElement.appendChild(iframe);
    iframe.parentNode.removeChild(iframe);
    iframe = null;
}

function searchInitialize() {
    var search = document.getElementById("search");
    search.addEventListener("keypress", searchKeyPress);
    search.addEventListener("focus", searchFocus);

    var send = document.getElementById("send");
    send.addEventListener("click", searchSendButton);
    var cancel = document.getElementById("cancel");
    cancel.addEventListener("click", searchCancel);

    searchCall("initialize", "");
}

function searchFocus() {
    var selection = document.getElementById("selection");
    selection.style.display = "block";
    searchSetSelection();
    var send = document.getElementById("send");
    send.className = "send";
    var cancel = document.getElementById("cancel");
    cancel.className = "cancel";
}

function searchCancel() {
    var selection = document.getElementById("selection");
    selection.style.display = "none";
    var send = document.getElementById("send");
    send.className = "none";
    var cancel = document.getElementById("cancel");
    cancel.className = "none";
}

function searchSend(search) {
    searchCall("send", search);
    search.value = "";
    searchCancel();
}

function searchSendButton() {
    var search = document.getElementById("search");
    searchSend(search.value);
}

function searchKeyPress(ev) {
    var search = document.getElementById("search");
    if (ev.which == 13) {
        searchSend(search.value);
    }
    searchSetSelection(search.value, rootSectors);
}

function searchRemoveChildren(element) {
    while (element.lastChild) {
        element.removeChild(selection.lastChild);
    }
}

function searchFindSectors(value, sectors) {
    for (var index = 0; index != sectors.length; ++index) {
        var sector = sectors[index];
        if (-1 < value.indexOf(sector.tag)) {
            var result = searchFindSectors(value, sector.sectors);
            if (result.length) {
                return result;
            }
        }
    }
    return sectors;
}

function searchSetSelection() {
    var search = document.getElementById("search");
    var selection = document.getElementById("selection");
    searchRemoveChildren(selection);
    var sectors = searchFindSectors(search.value, rootSectors);
    for (var index = 0; index != sectors.length; ++index) {
        var sector = sectors[index];
        if (-1 == search.value.indexOf(sector.tag)) {
            var link = document.createElement("a");
            link.className = "sector";
            var text = document.createTextNode(sector.name);
            link.appendChild(text);
            (function() {
                var capture = sector;
                link.addEventListener("click", function(){ searchSectorAdd(capture); });
            })();
            selection.appendChild(link);
            selection.appendChild(document.createTextNode(" "));
        }
    }
}

function searchToggleState(button, matches, search) {
    if (button.className == "open") {
        matches.className = "closed";
        button.className = "closed"
        button.value = "+"
        searchCall("collapse", search);
    } else {
        matches.className = "open";
        button.className = "open"
        button.value = "-"
        searchCall("expand", search);
    }
}

function removeSearch(searchString) {
    var search = JSON.parse(searchString);
    var searches = document.getElementById("searches");
    var parent = document.getElementById("search:" + search.id);
    searches.removeChild(parent);
}

function searchAdd(searchString) {
    var search = JSON.parse(searchString);
    var parent = document.createElement("div");
    parent.className = "search";
    parent.id = "search:" + search.id;
    var head = document.createElement("div");
    head.className = "searchHead";

    var state = document.createElement("input");
    state.type = "button";
    state.value = search.state == "open"? "-": "+";
    state.className = search.state;
    head.appendChild(state);

    var dispid = document.createElement("div");
    dispid.className = "id";
    dispid.appendChild(document.createTextNode(search.id));
    head.appendChild(dispid);

    var buttons = document.createElement("div");
    buttons.className = "searchButtons";

    var del = document.createElement("input");
    del.type = "button";
    del.value = "x";
    del.className = "delete";
    buttons.appendChild(del);

    var map = document.createElement("input");
    map.type = "button";
    map.value = ">";
    map.className = "map";
    buttons.appendChild(map);

    head.appendChild(buttons);

    var paragraph = document.createElement("div");
    paragraph.className = "searchText";
    var text = document.createTextNode(search.search);
    paragraph.appendChild(text);
    head.appendChild(paragraph);
    parent.appendChild(head);

    var empty = document.createElement("div");
    empty.className = "searchEmpty";
    parent.appendChild(empty);

    var matches = document.createElement("div");
    matches.id = "matches:" + search.id;
    matches.className = search.state;
    parent.appendChild(matches);

    state.addEventListener("click", function() { searchToggleState(state, matches, search.id); });
    del.addEventListener("click", function() { searchCall("delete", search.id); });

    var searches = document.getElementById("searches");
    searches.insertBefore(parent, searches.firstChild);
}

function searchAddMatch(matchString) {
    var match = JSON.parse(matchString);
    var matches = document.getElementById("matches:" + match.searchId);
    
    var parent = document.createElement("div");
    parent.className = "match";
    parent.id = "match:" + match.searchId + "/" + match.matchId;

    var dispid = document.createElement("div");
    dispid.className = "id";
    dispid.appendChild(document.createTextNode(parent.id));
    parent.appendChild(dispid);

    parent.appendChild(document.createTextNode(match.search));
    if (matches.childNodes.length) {
        matches.insertBefore(parent, matches.firstChild);
    }
    else {
        matches.appendChild(parent);
    }
}

function searchRemoveMatch(matchString) {
    var match = JSON.parse(matchString);
    var matches = document.getElementById("matches:" + match.searchId);
    var node = document.getElementById("match:" + match.searchId + "/" + match.matchId);
    matches.removeChild(node);
}

var searchNextIdValue = 0; //-dk:TODO remove
function searchNextId() { //-dk:TODO remove
    return ++searchNextIdValue;
}

function searchSectorAdd(sector) {
    var search = document.getElementById("search");
    if (-1 == search.value.indexOf(sector.tag)) {
        search.value = sector.tag + " " + search.value;
    }
    searchSetSelection(search.value, rootSectors);
}
