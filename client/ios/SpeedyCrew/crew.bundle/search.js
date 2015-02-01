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

    var cancel = document.getElementById("cancel");
    cancel.addEventListener("click", searchCancel);

    searchCall("initialize", "");
}

function searchFocus() {
    var selection = document.getElementById("selection");
    selection.style.display = "block";
    searchSetSelection();
    var cancel = document.getElementById("cancel");
    cancel.className = "cancel";
}

function searchCancel() {
    var selection = document.getElementById("selection");
    selection.style.display = "none";
    var cancel = document.getElementById("cancel");
    cancel.className = "none";
}

function searchSend(search) {
    searchCall("send", search);
    searchAdd("{ \"id\":\"" + searchNextId() + "\", \"search\":\"" + search + "\", \"state\":\"open\" }");
}

function searchKeyPress(ev) {
    var search = document.getElementById("search");
    if (ev.which == 13) {
        searchSend(search.value);
        search.value = "";
        searchCancel();
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

function searchToggleState(button, matches) {
    if (button.className == "open") {
        matches.className = "closed";
        button.className = "closed"
        button.value = "+"
    } else {
        matches.className = "open";
        button.className = "open"
        button.value = "-"
    }
}

function searchAdd(searchString) {
    var search = JSON.parse(searchString);
    var parent = document.createElement("div");
    parent.className = "search";
    var head = document.createElement("div");
    head.className = "searchHead";

    var state = document.createElement("input");
    state.type = "button";
    state.value = search.state == "open"? "-": "+";
    state.className = search.state;
    head.appendChild(state);

    var map = document.createElement("input");
    map.type = "button";
    map.value = ">";
    map.className = "map";
    head.appendChild(map);

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
    matches.className = "open";
    parent.appendChild(matches);

    state.addEventListener("click", function() { searchToggleState(state, matches); });

    var searches = document.getElementById("searches");
    searches.insertBefore(parent, searches.firstChild);
}

function searchAddMatch(matchString) {
    var match = JSON.parse(matchString);
    var matches = document.getElementById("matches:" + match.searchId);
    
    var parent = document.createElement("div");
    parent.className = "match";
    var text = document.createTextNode(match.search);
    parent.appendChild(text);
    if (matches.childNodes.length) {
        matches.insertBefore(parent, matches.firstChild);
    }
    else {
        matches.appendChild(parent);
    }
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
