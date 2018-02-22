#! /usr/bin/zsh

LCOM='<!--\s+'
RCOM='-->'
SP='\s+'
CAT='CATEGORY\s+'
ANY='[0-9A-Za-z-]+\s+'

function wiki-files {
  for filename in $(egrep -Le "$LCOM$CAT$RCOM" $SOURCE/*.mkdn 2>/dev/null); do
    echo ${${filename%.mkdn}#$SOURCE/} 
  done | sort | uniq
}

function wiki-categories {
  for filename in $(egrep -le "$LCOM$CAT$RCOM" $SOURCE/*.mkdn 2>/dev/null); do
    echo ${${filename%.mkdn}#$SOURCE/} 
  done | sort | uniq
}

function wiki-files-category {
  for filename in $(egrep -le "$LCOM$CAT$1$SP$RCOM" $SOURCE/*.mkdn 2>/dev/null); do
    echo ${${filename%.mkdn}#$SOURCE/} 
  done | sort | uniq
}

function wiki-file-categories {
  for _ _ filename _ in $(egrep -hoe "$LCOM$CAT$ANY$RCOM" $SOURCE/$1.mkdn 2>/dev/null); do
    echo $filename
  done | sort | uniq
}

function wiki-get-title {
  (egrep -he '^%' $SOURCE/$1.mkdn 2>/dev/null || echo "% $1") | head -n1 | sed 's/^%\s*//g'
}

function wiki-format-reference {
  echo '- ['$(wiki-get-title $1)'](./'$1'.html)'
}

function wiki-category-listing {
  if egrep -qe $LCOM$CAT$RCOM $SOURCE/$1.mkdn; then
    echo >> $TARGET/$1.mkdn
    echo >> $TARGET/$1.mkdn
    echo '# Category Pages' >> $TARGET/$1.mkdn
    for file in $(wiki-files-category $1); do
      wiki-format-reference $file >> $TARGET/$1.mkdn
    done
  fi
}

function wiki-member-listing {
  if egrep -qe $LCOM$CAT$ANY$RCOM $SOURCE/$1.mkdn; then
    echo >> $TARGET/$1.mkdn
    echo >> $TARGET/$1.mkdn
    echo '# Listed Under' >> $TARGET/$1.mkdn
    for file in $(wiki-file-categories $1); do
      wiki-format-reference $file >> $TARGET/$1.mkdn
    done
  fi
}

function wiki-make-tmp {
  t=$TARGET/$1.mkdn
  s=$SOURCE/$1.mkdn 
  if [[ -e $s ]]; then
    cat $s >> $t
  else
    echo '%' $1 >> $t
  fi
}

function wiki-trappings {
  cat >> $TARGET/basic-style.css <<CSS
  body {
    width: 1000px;
    margin-left: 100px;
    margin-right: 100px;
    margin-top: 100px;
    font-family: Fira Mono;
    font-size: 12pt;
  }
  a.redlink {
    color: red;
  }
  a.redlink:active {
    color: orange;
  }
CSS
  cat >> $TARGET/redlinks.js <<JS
  (function() {
    var anchors = document.getElementsByTagName("a");
    var url = new URL(document.URL);
    for (var i = 0; i < anchors.length; i++) {    
      var a = anchors[i];
      var u = new URL(a.href);
      if (u.host == url.host && u.pathname != url.pathname) {
        var req = new XMLHttpRequest;
        req.open('HEAD', a.href, false);
        req.onreadystatechange = function() {
          if (req.readyState == XMLHttpRequest.DONE) {
            if (req.status != 200) {
              a.className += ' redlink';  
            }
          }
        }
        req.send();
      }
    }
  })();
JS
}

function wiki-add-js {
  echo >> $TARGET/$1.mkdn
  echo >> $TARGET/$1.mkdn
  echo "<script src=\"./redlinks.js\"></script>" >> $TARGET/$1.mkdn
}


function wiki-pandoc {
  pandoc --toc -sS -f markdown+pandoc_title_block --css ./basic-style.css -t html -o $TARGET/$1.html $TARGET/$1.mkdn
  rm -f $TARGET/$1.mkdn
}

function wiki-listings {
  echo >> $TARGET/$1.mkdn
  echo >> $TARGET/$1.mkdn
  echo '# Categories' >> $TARGET/$1.mkdn
  for file in $(wiki-categories); do
    wiki-format-reference $file >> $TARGET/$1.mkdn
  done
  echo >> $TARGET/$1.mkdn
  echo >> $TARGET/$1.mkdn
  echo '# Pages' >> $TARGET/$1.mkdn
  for file in $(wiki-files); do
    [[ $file == index ]] && continue
    wiki-format-reference $file >> $TARGET/$1.mkdn
  done
}

function wiki-make {
  wiki-trappings

  wiki-make-tmp index
  wiki-listings index
  wiki-pandoc index

  for name in $(wiki-categories); do
    wiki-make-tmp $name
    wiki-category-listing $name
    wiki-member-listing $name
    wiki-add-js $name
    wiki-pandoc $name
  done
  for name in $(wiki-files); do
    [[ $name == index ]] && continue
    wiki-make-tmp $name
    wiki-member-listing $name
    wiki-add-js $name
    wiki-pandoc $name
  done
}

if [[ ! -o interactive ]]; then
  if [[ ! $SOURCE ]] || [[ ! $TARGET ]]; then
    (echo need \$SOURCE and \$TARGET >&2)
    exit 1
  fi
  wiki-make
fi
