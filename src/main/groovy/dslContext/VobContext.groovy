package dslContext

@Grab('org.slf4j:slf4j-simple:1.7.7')
import groovy.util.logging.Slf4j
import migration.clearcase.Vob
import utils.StringExtensions

@Slf4j
class VobContext {
    Vob vob

    /**
     * VobContext constructor
     * @param name the Vob name
     */
    public VobContext(String name) {
        log.debug('Entering VobContext().')
        def parseResult = StringExtensions.parseClearCaseName(name)
        vob = new Vob(parseResult.vob)
        log.info('Vob {} registered for migration.', vob.name)
        log.debug('Exiting VobContext().')
    }

    /**
     * Adds a Component to the Vob
     * @param name the Component name
     * @param closure the ComponentContext configuration
     */
    def void component(String name, @DelegatesTo(ComponentContext) Closure closure) {
        log.debug('Entering component().')
        def componentContext = new ComponentContext(name)
        def componentClosure = closure.rehydrate(componentContext, this, this)
        componentClosure.resolveStrategy = Closure.DELEGATE_ONLY
        componentClosure.run()
        vob.components.add(componentContext.component)
        log.info('Added Component {} to Vob {}.', componentContext.component.name, vob.name)
        log.debug('Exiting component().')
    }
}
