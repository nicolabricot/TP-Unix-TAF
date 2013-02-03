#! /bin/sh
# Nicolas Devenet

DATA="./.data"
TAF="./taf.html"
TAFS="./tafs.html"
MONTH=`date +"%b"`

initialization() {
  rm -vf $TAF
  rm -vf $TAFS
  rm -vrf $DATA
  echo "> Initialization done"
}

download() {
  if test ! -e $DATA
    then mkdir $DATA
  fi
  case $1 in
    de|fr|it|bl|es|as|ch)
      if test ! -r $DATA/taf-$1.htm
        then curl -o $DATA/taf-$1.htm -f http://wx.rrwx.com/taf-$1.htm
      fi
      if test ! -r $DATA/taf-$1-txt.htm
        then curl -o $DATA/taf-$1-txt.htm -f http://wx.rrwx.com/taf-$1-txt.htm
      fi;;
    *) echo "> Invalid country";;
  esac
}

extract() {
  rm -f $DATA/airport
  if test -r $DATA/taf-$1.htm -a -r $DATA/taf-$1-txt.htm
    then
      if test `grep -ic "$2" < $DATA/taf-$1.htm` -eq 1
        then
          grep -i "$2" < $DATA/taf-$1.htm > $DATA/temp
          code_airport=`sed -n 's:.*<b>\([A-Z][A-Z][A-Z][A-Z]\)</b>.*:\1:p' < $DATA/temp`
          grep $code_airport < $DATA/taf-$1-txt.htm > $DATA/airport
          #temp=`tr '[ ]' '[\n]' < $DATA/airport`
          #echo $temp > $DATA/airport
          echo "> Airport $code_airport ($2) loaded"          
        else echo "> Airport not found"
      fi
  else echo "> No file found"
  fi
  rm -f $DATA/temp*
}

analyze() {
  if test -r $DATA/airport
    then
      if test "$1"
        then OUT=$TAFS
      else
        OUT=$TAF
        echo "<!doctype html>" > $TAF
      fi
      set -- `cat $DATA/airport`
      if test $OUT != $TAFS
        then analyse_html_header $1 $TAF
      fi
      if test "$2" = "AMD"
        then
          analyse_html_top $1 $3 $4 true
          shift 4
        else
          analyse_html_top $1 $2 $3
          shift 3
      fi
      while [ $# != 0 ]; do
        if test "$1" = "TEMPO"
          then echo "</ul><h2>Temporary</h2><ul>" >> $OUT
        elif test "$1" = "BECMG"
          then echo "</ul><h2>Becoming</h2><ul>" >> $OUT
        elif expr "$1" : '^PROB.*' > /dev/null
          then analyse_prob "$1"
        elif test "$1" = "CAVOK"
          then echo "<li>Clouds: OK</li>" >> $OUT
        elif expr "$1" : '^[FEWSCTBKNOVC]\{3\}[0-9]\{3\}' > /dev/null
          then analyse_cloud "$1"
        elif expr "$1" : '^\([0-9]*\)/.*' > /dev/null
          then analyse_periode "$1"
        elif expr "$1" : '.*KT$' > /dev/null
          then analyse_winds "$1"
        elif expr "$1" : '^[0-9]\{4\}$' > /dev/null
          then analyse_visibility "$1"
        fi
        shift
      done;
      analyse_html_footer
      if test $OUT = $TAF
        then echo "> Result written in taf.html"
      fi
  fi
}

analyse_visibility() {
  if test "$1" -eq 0000
    then visibility="< 50 m"
  elif test "$1" -eq 9999
    then visibility="> 10 km"
  else visibility="$1 m"
  fi
  echo "<li>Visibility: $visibility </li>" >> $OUT
}

analyse_cloud() {
  type=`expr "$1" : '^\([A-Z]\{3\}\).*'`
  if test "$type" = "FEW"
    then type="few"
  elif test "$type" = "SCT"
    then type="scatered"
  elif test "$type" = "BKN"
    then type="broken"
  elif test "$type" = "OVC"
    then type="overcast"
  fi
  echo "<li>Clouds: $type at `expr "$1" : '.*\([0-9][0-9][0-9]\)'`00 ft</li>" >> $OUT
}

analyse_prob() {
  prob=`expr $1 : '^.*\([0-9][0-9]\)'`
  echo "</ul><h2>Probability $prob%</h2><ul>" >> $OUT
}

analyse_periode() {
  day_begin=`expr "$1" : '^\([0-9][0-9]\)'`
  hour_begin=`expr "$1" : '^[0-9][0-9]\([0-9][0-9]\)'`
  day_end=`expr "$1" : '.*/\([0-9][0-9]\)'`
  hour_end=`expr "$1" : '.*\([0-9][0-9]\)$'`
  echo "<li>Periode: $day_begin $MONTH at $hour_begin:00 &rarr; $day_end $MONTH at $hour_end:00</li>" >> $OUT
}

analyse_winds() {
  data=`expr "$1" : '\(.*\)KT$'`
  if test "$data" != "00000"
    then
      direction=`expr "$data" : '^\([A-Z0-9][A-Z0-9][A-Z0-9]\)'`
      if test "$direction" = "VRB"
        then direction="variable"
        else direction="$direction&deg;"
      fi
      knot=`expr "$data" : '^[A-Z0-9][A-Z0-9][A-Z0-9]\([0-9][0-9]\)'`
      echo "<li>Wind: $direction at $knot KT" >> $OUT
      rafale=`expr "$data" : '.*G\([0-9][0-9]\)'`
      if test "$rafale" != ""
        then echo " (bursts at $rafale KT)" >> $OUT
      fi
      echo "</li>" >> $OUT
  else echo "<li>Wind: calm</li>" >> $OUT
 fi
}

analyse_html_top() {
  day=`expr "$2" : '^\([0-9][0-9]\)'`
  hour=`expr "$2" : '^[0-9][0-9]\([0-9][0-9]\)'`
  minute=`expr "$2" : '[0-9]\{4\}\([0-9][0-9]\)'`
  periode_begin_day=`expr "$3" : '^\([0-9][0-9]\)'`
  periode_begin_hour=`expr "$3" : '^[0-9][0-9]\([0-9][0-9]\)'`
  periode_end_day=`expr "$3" : '^.*/\([0-9][0-9]\)'`
  periode_end_hour=`expr "$3" : '^.*\([0-9][0-9]\)$'`
  echo "<h1>TAF : $1</h1>
<p>`cat $DATA/airport`</p>
<ul>" >> $OUT
  if test "$4"; then echo "<li><strong>Amendement</strong></li>" >> $OUT; fi
  echo "<li>Airport: $1</li>
<li>Emitted: $day $MONTH at $hour:$minute</li>
<li>Periode: $periode_begin_day $MONTH at $periode_begin_hour:00 &rarr; $periode_end_day $MONTH at $periode_end_hour:00</li>" >> $OUT
}
analyse_html_header() {
 echo "<html>
<head>
    <meta charset="UTF-8" />
  <title>TAF : $1</title>
</head>
<body>" >> $2
}
analyse_html_footer() {
  echo "</ul>
</body>
</html>" >> $OUT
}

case $1 in
  -i)
    initialization;;
  -d)
    if test $# -ge 2
      then download "$2"
    else echo "> Country missed"
    fi;;
  -e)
    if test $# -ge 3
      then extract "$2" "$3"
    else echo "> Country or airport missed"
    fi;;
  -a)
    if test -r $DATA/airport
      then analyze
    else echo "> Please select an airport before"
    fi;;
  -p)
    if test $# -ge 3
      then
        download "$2"
        extract "$2" "$3"
        analyze
    else echo "> Country or airpot missed"
    fi;;
  -t)
    if test $# -ge 3
      then
        shift 1
        echo "<!doctype html>" > $TAFS
        analyse_html_header "TAFS" $TAFS
        while test $# -ge 2; do
          download "$1"
          extract "$1" "$2"
          analyze true
          shift 2
        done
        cp $TAFS $TAF
        rm -f $TAFS
        echo "> Results written in taf.html"
    else echo "> Missing argument"
    fi;;
  *)
    echo "> Nothing to do :)"
    echo "  Try :"
    echo "   -i to initialize"
    echo "   -d [country] to download files of a country"
    echo "   -e [country] [airport] to choose an airport from the country"
    echo "   -a to get TAF of the airport previously selected"
    echo "   -p [country] [airport] to get directly TAF of a airport"
    echo "   -t [[country] [airport]] to get TAFs of a fly";;
esac
