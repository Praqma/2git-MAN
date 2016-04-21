package migration.sources.ccucm.context

import context.base.Context
import groovy.util.logging.Slf4j
import migration.sources.ccucm.extractions.BaselineProperty

@Slf4j
trait CcucmExtractionsContext implements Context {

    /**
     * Extracts a CoolBaseline property
     * @param map A map of values to extract and keys to map them to.
     */
    void baselineProperty(Map<String, String> map) {
        extractions.add(new BaselineProperty(map))
        log.info("Added 'baselineProperty' criteria.")
    }
}
