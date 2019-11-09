node {
    checkout scm

    stage('Tidy Up') {
        sh 'make dirclean'
    }

    stage('Configure') {
        sh 'cat .jenkins/config.seed > .config'
        sh 'make defconfig'
    }

    stage('Update Packages Feed') {
        sh 'scripts/feeds update packages'
        sh 'scripts/feeds install -a -p packages'
    }

    stage('Re-Configure') {
        sh 'cat .jenkins/config.seed > .config'
        sh 'make defconfig'
    }

    stage('Download Sources') {
        sh 'make download'
    }

    stage('Build') {
        sh 'make -j8 V=s || make -j1 V=s'
    }
}
