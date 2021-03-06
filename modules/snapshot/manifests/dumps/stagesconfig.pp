class snapshot::dumps::stagesconfig {

    include snapshot::dumps::dirs
    $confsdir = $snapshot::dumps::dirs::confsdir

    $firststage_args = '--cutoff {STARTDATE} --date {STARTDATE}'
    $rest_args = '--date {STARTDATE} --onepass'
    $wikiargs = '/bin/bash ./worker --skipdone --exclusive --log'

    $args_smallwikis = "${wikiargs} --configfile ${confsdir}/wikidump.conf"
    $args_bigwikis = "${wikiargs} --configfile ${confsdir}/wikidump.conf.bigwikis"
    $args_hugewikis = "${wikiargs} --configfile ${confsdir}/wikidump.conf.hugewikis"

    $jobs_to_skip = join(['metahistorybz2dump',
                          'metahistorybz2dumprecombine',
                          'metahistory7zdump',
                          'metahistory7zdumprecombine'], ',')

    $stages = {
        smallwikis   => {
            firststage => "${args_smallwikis} ${firststage_args}",
            rest       => "${args_smallwikis} ${rest_args}",
        },
        bigwikis     => {
            firststage => "${args_bigwikis} ${firststage_args}",
            rest       => "${args_bigwikis} ${rest_args}",
        },
        hugewikis    => {
            firststage => "${args_hugewikis} ${firststage_args}",
            rest       => "${args_hugewikis} ${rest_args}",
        },
        skipjob_args => "--skipjobs ${jobs_to_skip}",
    }

    snapshot::dumps::stagesconf { 'stages_normal':
        stagestype => 'normal',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_partial':
        stagestype => 'partial',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_normal_nocreate':
        stagestype => 'normal_nocreate',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_partial_nocreate':
        stagestype => 'partial_nocreate',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_normal_hugewikis':
        stagestype => 'normal_huge',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_partial_hugewikis':
        stagestype => 'partial_huge',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_normal_nocreate_hugewikis':
        stagestype => 'normal_nocreate_huge',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_partial_nocreate_hugewikis':
        stagestype => 'partial_nocreate_huge',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_create':
        stagestype => 'create',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_create_smallwikis':
        stagestype => 'create_small',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_create_bigwikis':
        stagestype => 'create_big',
        stages     => $stages,
    }
    snapshot::dumps::stagesconf { 'stages_create_hugewikis':
        stagestype => 'create_huge',
        stages     => $stages,
    }
}
