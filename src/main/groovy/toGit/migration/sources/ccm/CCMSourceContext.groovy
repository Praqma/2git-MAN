package toGit.migration.sources.ccm

import toGit.context.base.Context
import toGit.context.traits.SourceContext


class CCMSourceContext implements Context, SourceContext {
    public CCMSourceContext() {
        source = new CCMSource()
    }


    /**
     * Sets the source workspace
     */
    void workspace(String path) {
        source.workspace = path
        //log.debug("Set workspace to $path.")
    }

    void revision (String revision){
        source.revision = revision
    }

    void ccm_addr (String ccm_addr){
        source.ccm_addr = ccm_addr
    }

    void submodule_paths (String[] submodule_paths){
        source.submodule_paths = submodule_paths
    }
}
