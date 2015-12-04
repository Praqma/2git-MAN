migrate('E:\\cc-to-git') {
    vob('\\2Cool_PVOB') {
        component('Model') {
            migrationOptions {
                git {
                    ignore '.jnk'
                    user 'praqma'
                    email 'support@praqma.net'
                }
            }
            stream('server_dev2') {
                migrationSteps {
                    filter {
                        criteria {
                            afterDate 'dd-MM-yyyy', '31-05-1991'
                            baselineName 'v\\d{3}.*'
                        }
                        extractions {
                            baselineProperty([name: 'shortname'])
                        }
                        actions {
                            git 'add -A'
                            git 'commit -m\"$name\"'
                        }
                    }
                    filter {
                        criteria {
                            afterBaseline 'v100@\\2Cool_PVOB'
                            promotionLevels 'RELEASED'
                        }
                        extractions {
                            baselineProperty([level: 'promotionLevel'])
                        }
                        actions {
                            git 'tag \"$level-$name\"'
                        }
                    }

                }
            }
        }
    }
}