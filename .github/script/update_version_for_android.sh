#!/bin/bash

rtt=$GIT_BRANCH_IMAGE_VERSION
rc=$(git rev-parse --short HEAD)
rb=$(git rev-parse --abbrev-ref HEAD)
# 获取当前分支的最新tag
currtag=$(git describe --tags --match "v[0-9]*" --abbrev=0 HEAD)
currbra=$rb
echo 000---$currtag
echo 111---$rtt
echo 222---$rc
echo 333---$rb

# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch
vtag=${currtag#*v}
echo $vtag

branch=${currbra#*v}

# 判断分支名是否是 vX.Y.x 或 vX.Y.x-fixbug（精确匹配），如果是则走 tag 自增逻辑
# 其他分支（如 vX.Y.x-log、vX.Y.x-fixbug01 等）使用分支名作为版本号
if [[ "$branch" =~ ^[0-9]+\.[0-9]+\.x$ ]] || [[ "$branch" =~ ^[0-9]+\.[0-9]+\.x-fixbug$ ]]; then
    vbranch=${branch%x*}0
    echo "vbranch: $vbranch"

    function version_ge(){
        test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1";
    }

    resultvv=$vbranch
    if version_ge $vtag $vbranch; then
        echo "$vtag is greater than or equal to $vbranch"

        vtaglist=(${vtag//./ })

        firsttag=${vtaglist[0]}
        secondtag=${vtaglist[1]}
        thirdtag=${vtaglist[2]}
        thirdtag=`expr $thirdtag + 1`

        resultvv=$firsttag.$secondtag.$thirdtag
    fi
else
    # 其他分支使用分支名作为版本号
    resultvv=$branch
    echo "use branch name as version: $resultvv"
fi

echo "-->>$resultvv"

if [ "$1" = "Debug" ]; then
	sed -i 's#def libVersion.*#def libVersion = \"'$resultvv'-SNAPSHOT\"#g' $2
	echo "libVersion-->>$resultvv-SNAPSHOT"
else
	sed -i 's#def libVersion.*#def libVersion = \"'$vtag'\"#g' $2
	echo "libVersion-->>$vtag"
fi
# ==========此处添加版本自增逻辑，如果是持续集成发snapshot，最新tag+1；如果是发布就发branch


