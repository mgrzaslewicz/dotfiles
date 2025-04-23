# maven
alias mtc="mvn test-compile"
alias mdep="mvn dependency:tree | tee /tmp/deptree"
alias vmdep="vim /tmp/deptree"

## keep any file created for analyzing logs out of project folder
## aliases suffixed with *l mean show the log file
mct() {
  mvn clean test > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log #print success only or else show nothing
}
mctl() {
  (mvn clean test > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log) || vim $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
mt() {
  mvn test > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
mtl() {
  (mvn test > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log) || vim $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
mcp() {
  mvn clean package > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log #print success only or else show nothing
}
mcpl() {
  (mvn clean package > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log) || vim $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
mci() {
  mvn clean install > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log #print success only or else show nothing
}
mcil() {
  (mvn clean install > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log) || vim $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
mist() {
  mvn install -DskipTests > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log #print success only or else show nothing
}
mistl() {
  (mvn install -DskipTests > $MY_TMP/$(basename $(pwd))-build.log && tail $MY_TMP/$(basename $(pwd))-build.log) || vim $MY_TMP/$(basename $(pwd))-build.log #print success or view full log on failure
}
vl() {
  vim $MY_TMP/$(basename $(pwd))-build.log #view full log with vim
}

mcloneci() {
  repoPath=`pwd`
  repoName=$(basename $(pwd))
  rm -rf $MY_TMP/$repoName
  cd $MY_TMP
  git clone file://$repoPath $repoName
  mvn clean install
  cd $repoPath
}
