package toGit.migration.sources.ccm

import org.apache.commons.io.FileUtils
import org.slf4j.LoggerFactory

import toGit.context.base.Context
import toGit.migration.plan.Criteria
import toGit.migration.plan.Snapshot
import toGit.migration.sources.MigrationSource
import toGit.migration.sources.ccm.context.CcmCriteriaContext
import toGit.migration.sources.ccm.context.CcmExtractionsContext

class CCMSource implements MigrationSource {

    final static log = LoggerFactory.getLogger(this.class)

    String revision
    String proj_instance
    String name4part
    String ccm_addr
    String ccm_home
    String system_path
    String jiraProjectKey


    @Override
    List<Snapshot> getSnapshots(List<Criteria> initialFilter) {

        List<Snapshot> projects

        // Build the CCM project conversion list
        def sout = new StringBuilder(), serr = new StringBuilder()
        def cmd_line = "bash " + System.getProperty("user.dir") + File.separator + "ccm-baseline-history.sh $name4part"
        log.info cmd_line.toString()

        def envVars = System.getenv().collect { k, v -> "$k=$v" }
        def cmd = cmd_line.execute(envVars,new File(workspace))
        cmd.waitForProcessOutput(sout, serr)
        def exitValue = cmd.exitValue()

        println (sout.toString())
        if ( exitValue ){
            println ("Standard error output" )
            println (serr.toString())
            throw new Exception("ccm-baseline-history gave an non-0 exit code" )
        }
        if ( serr.toString().readLines().size() > 0 ){
            println ("Standard error output - used for SKIP projects" )
            println (serr.toString())
        }

        projects = sout.readLines().collect{new Snapshot(it){}}

        log.info projects.size().toString()

        return projects
    }

    @Override
    void checkout(Snapshot snapshot) {
        copy2Filesystem(snapshot.identifier.split("@@@")[0])
    }

    private void copy2Filesystem(String project) {
        def project_revision_for_ws=project.split(":")[0]

        def codeFile = new File(workspace, "code")
        codeFile.parentFile.mkdirs()
        if ( ! codeFile.exists()) {
            codeFile.delete()
        }
        codeFile.mkdir()
        //Get the revision without instance

        if ( new File(workspace + "/code/" + project_revision_for_ws).exists()){
            log.info "CM/Synergy checkout: Skipping project revision: ${project} - already exists"
        } else {
            def sout = new StringBuilder(), serr = new StringBuilder()
            def file_tmp = new File(workspace + "/code/" + project_revision_for_ws + "_tmp")
            if ( file_tmp.exists() ){
                log.info workspace + "/code/" + project_revision_for_ws + "_tmp exist - Delete it "
                file_tmp.deleteDir()
            }

            def envVars = System.getenv().collect { k, v -> "$k=$v" }
            def project_revision_with_spaces = project.replaceAll("xxx"," ")
            def cmd_line = ["ccm", "copy_to_file_system", "-p", "${project_revision_for_ws}_tmp", "-r", "${project_revision_with_spaces}"]
            log.info "'" + cmd_line + "'"
            def cmd = cmd_line.execute(envVars,codeFile)
            cmd.waitForProcessOutput(sout, serr)
            def exitValue = cmd.exitValue()
            log.info "Standard out:"
            log.info "'" + sout + "'"
            log.info "Standard error:"
            log.info "'" + serr + "'"
            log.info "Exit code: " + exitValue
            if ( exitValue ){
                throw new Exception("ccm copy_to_file_system gave an non-0 exit code" )
            }
            if ( serr.toString().readLines().size() > 0 ){
                throw new Exception("ccm copy_to_file_system standard error contains text lines: " + serr.toString().readLines().size() )
            }
            def path_tmp=workspace + "/code/" + project_revision_for_ws + "_tmp"
            def path_final=workspace + "/code/" + project_revision_for_ws
            def file_full_path_name=workspace + "/code/" + project_revision_for_ws + "/" + project_revision_with_spaces.split('~')[0]

            log.info "Move from: ${path_tmp} to: ${path_final}"
            FileUtils.moveDirectory(new File(path_tmp), new File(path_final))
            if ( file_full_path_name.contains(' ') ){
                log.info "Project revision contains [spaces] - replace with xxx's"
                FileUtils.moveDirectory(
                        new File( file_full_path_name )
                        ,
                        new File(file_full_path_name.replaceAll(' ','xxx')))
            }

        }


    }

    @Override
    void prepare() {

    }

    @Override
    void cleanup() {

    }

    @Override
    Context withCriteria(Context criteriaContext) {
        return criteriaContext as CcmCriteriaContext
    }

    @Override
    Context withExtractions(Context extractionsContext) {
        return extractionsContext as CcmExtractionsContext
    }
}
