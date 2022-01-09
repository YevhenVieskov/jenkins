pipeline{
    agent none
    stages {
        stage("first"){
            steps {
                //timestamps {
                      logstash{ 
                       echo "hello world 1"
                      }
                  
                //}
            }
        }
        stage("second"){
            steps{
                //timestamps {
                    logstash {
                        echo "hello world 2"
                    }
                //}
            }
        }
    }
}