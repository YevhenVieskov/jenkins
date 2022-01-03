@Library('jenkins-repository') _
node {
    stage("Checkout") {
        ...
        checkout scm 
    }
    stage ("Run Test") {
        ...k6 run --out json=results.json src/integration_tests/integration.js ...           k6JsonToJunitXml("results.json", "output.xml")...
    stage ("Reports"){
        ...
    }
}
