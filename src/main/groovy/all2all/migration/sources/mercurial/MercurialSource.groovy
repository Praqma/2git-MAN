package all2all.migration.sources.mercurial

import all2all.context.base.Context
import all2all.migration.plan.Criteria
import all2all.migration.plan.Snapshot
import all2all.migration.sources.MigrationSource
import all2all.migration.sources.mercurial.context.MercurialCriteriaContext
import all2all.migration.sources.mercurial.context.MercurialExtractionsContext

class MercurialSource implements MigrationSource {

    String branch
    String sourceRepo
    String repoName
    boolean hasSubrepos
    Runtime rt = Runtime.getRuntime()
    ProcessBuilder builder
    Process pr
    String sourceClonePath = "output/source/sourceClone/$repoName"

    @Override
    List<Snapshot> getSnapshots(List<Criteria> criteria) {
        builder = new ProcessBuilder("bash", "-c", "cd $sourceClonePath; hg log  -T \"{node},{date|shortdate}\\n\"")
        builder.redirectErrorStream(true)
        pr = builder.start()
        BufferedReader stdInput = new BufferedReader(new InputStreamReader(pr.getInputStream()))
        String output
        List<Snapshot> snapshots = []
        while ((output = stdInput.readLine()) != null) {
            def values = output.split(',')
            MercurialChangeset commit = new MercurialChangeset(values[0])
            commit.date = new Date().parse("yyyy-MM-dd", values[1])
            snapshots.add(commit)
        }
        return snapshots.reverse()
    }

//    //wo criteria test version
//    List<Snapshot> getSnapshots() {
//        builder = new ProcessBuilder(
//                "bash", "-c","cd output/source/sourceClone/$repoName; hg log  --template \"{node}\\n\"")
//        builder.redirectErrorStream(true);
//        pr = builder.start();
//        BufferedReader stdInput = new BufferedReader(new
//                InputStreamReader(pr.getInputStream()));
//        String s = null;
//        List<Snapshot> snapshots = []
//        while ((s = stdInput.readLine()) != null) {
//            MercurialChangeSet commit = new MercurialChangeSet(s)
//            println commit.identifier
//            snapshots.add(commit)
//        }
//        return snapshots
//
//    }

    @Override
    void checkout(Snapshot snapshot) {
        def id = ((MercurialChangeset) snapshot).identifier
        File f = new File(workspace)
        if (f.exists() && f.isDirectory()) {
            pr = rt.exec("rm -R $workspace")
        }
        builder = new ProcessBuilder(
                "bash", "-c", "cd output;mkdir source; cd source;mkdir temp; cd temp;  hg clone -r $id $sourceRepo")
        builder.redirectErrorStream(true)
        builder.start()
    }

//    //pre snapshot testing
//    void checkout(String id) {
//        File f = new File(dir)
//        if (f.exists() && f.isDirectory()) {
//            pr = rt.exec("rm -R $dir")
//        }
//        builder = new ProcessBuilder(
//                "bash", "-c","cd output;mkdir source; cd source;mkdir temp; cd temp;  hg clone -r $id $sourceRepo")
//        builder.redirectErrorStream(true);
//        Process p = builder.start();
//    }

    @Override
    void prepare() {

        if (hasSubrepos) {
            setupSubrepos() {}
        }

        cloneRemote()

        //checkout ("66c87efa37b1")
        //getSnapshots()
    }

    @Override
    void cleanup() {

    }

    @Override
    Context withCriteria(Context criteriaContext) {
        return criteriaContext as MercurialCriteriaContext
    }

    @Override
    Context withExtractions(Context extractionsContext) {
        return extractionsContext as MercurialExtractionsContext
    }

    void cloneRemote() {
        builder = new ProcessBuilder("bash", "-c", "cd output;mkdir source; cd source; mkdir sourceClone; cd sourceClone; hg clone $sourceRepo")
        builder.redirectErrorStream(true)
        builder.start()
    }
}
