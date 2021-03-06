//
//     ____    _                        __     _      _____
//    / ___\  /_\     /\/\    /\ /\    /__\   /_\     \_   \
//    \ \    //_\\   /    \  / / \ \  / \//  //_\\     / /\/
//  /\_\ \  /  _  \ / /\/\ \ \ \_/ / / _  \ /  _  \ /\/ /_
//  \____/  \_/ \_/ \/    \/  \___/  \/ \_/ \_/ \_/ \____/
//
//	Copyright Samurai development team and other contributors
//
//	http://www.samurai-framework.com
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.
//

#import "Samurai_CssProtocol.h"
#import "Samurai_CssParser.h"
#import "Samurai_HtmlMediaQuery.h"

#import "_pragma_push.h"

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

#import "katana.h"

// ----------------------------------
// Source code
// ----------------------------------

typedef NS_ENUM(NSUInteger, SamuraiCssSelectorMatch) {
    SamuraiCssSelectorMatches,
    SamuraiCssSelectorFailsLocally,
    SamuraiCssSelectorFailsAllSiblings,
    SamuraiCssSelectorFailsCompletely,
};

@class SamuraiCssRuleData;
@class SamuraiCssRuleCollector;
@class SamuraiCssRuleSet;
@class SamuraiCssSelectorChecker;

#pragma mark - SamuraiCssRuleData

@interface SamuraiCssRuleData : NSObject
@property (nonatomic, assign, readonly) NSUInteger      position;
@property (nonatomic, assign, readonly) NSUInteger      specificity;
@property (nonatomic, assign, readonly) KatanaStyleRule * rule;
@property (nonatomic, assign, readonly) KatanaSelector  * selector;
- (instancetype)initWithRule:(KatanaStyleRule *)rule selector:(KatanaSelector *)selector position:(NSUInteger)position;
@end

#pragma mark - SamuraiCssValueWrapper

@implementation SamuraiCssValueWrapper

- (NSString *)description
{
    return self.rawValue;
}

@end

#pragma mark - SamuraiCssRuleData

@interface SamuraiCssRuleData ()
@property (nonatomic, readwrite) NSUInteger specificity;
@end

@implementation SamuraiCssRuleData

- (instancetype)initWithRule:(KatanaStyleRule *)rule
                    selector:(KatanaSelector *)selector
                    position:(NSUInteger)position
{
    self = [super init];
    if (self) {
        _rule = rule;
        _specificity = ULONG_MAX;
        _position = position;
        _selector = selector;
    }
    return self;
}

- (NSUInteger)specificity
{
    if ( _specificity == ULONG_MAX ) {
        _specificity = katana_calc_specificity_for_selector(_selector);
    }
    return _specificity;
}

@end


#pragma mark - SamuraiCssRuleSet

@interface SamuraiCssRuleSet : NSObject

@property (nonatomic, strong) id<SamuraiCssMediaQueryChecker> mediaQueryChecker;

- (NSArray *)universalRules;
- (NSArray *)idRulesWithKey:(NSString *)key;
- (NSArray *)tagRulesWithKey:(NSString *)key;
- (NSArray *)classRulesWithKey:(NSString *)key;
- (NSArray *)pseudoRulesWithKey:(NSString *)key;

- (void)clear;

- (void)addRulesFromSheet:(KatanaStylesheet *)sheet;
- (void)mergeWithRuleSet:(SamuraiCssRuleSet *)ruleSet;

@end

@interface SamuraiCssRuleSet()
@property (nonatomic, assign) NSUInteger ruleCount;
@property (nonatomic, strong) NSMutableDictionary * idRules;
@property (nonatomic, strong) NSMutableDictionary * classRules;
@property (nonatomic, strong) NSMutableDictionary * tagRules;
@property (nonatomic, strong) NSMutableDictionary * shadowPseudoElementRules;
@property (nonatomic, strong) NSMutableDictionary * pseudoRules;
@property (nonatomic, strong) NSMutableArray * linkPseudoClassRules;
@property (nonatomic, strong) NSMutableArray * focusPseudoClassRules;
@property (nonatomic, strong) NSMutableArray * privateUniversalRules;
@property (nonatomic, strong) NSMutableArray * fontFaceRules;
@property (nonatomic, strong) NSMutableArray * keyframesRules;

@end

@implementation SamuraiCssRuleSet

- (id)init
{
    self = [super init];
    
    if ( self )
    {
        _idRules = [NSMutableDictionary dictionary];
        _classRules = [NSMutableDictionary dictionary];
        _tagRules = [NSMutableDictionary dictionary];
        _shadowPseudoElementRules = [NSMutableDictionary dictionary];
        _linkPseudoClassRules = [NSMutableArray array];
        _pseudoRules = [NSMutableDictionary dictionary];
        _focusPseudoClassRules = [NSMutableArray array];
        _privateUniversalRules = [NSMutableArray array];
        _fontFaceRules = [NSMutableArray array];
        _keyframesRules = [NSMutableArray array];
    }
    
    return self;
}

- (void)dealloc
{
    [self clear];
    
    self.idRules               = nil;
    self.tagRules              = nil;
    self.classRules            = nil;
    self.pseudoRules           = nil;
    self.privateUniversalRules = nil;
}

- (void)clear
{
    [self.idRules removeAllObjects];
    [self.tagRules removeAllObjects];
    [self.classRules removeAllObjects];
    [self.pseudoRules removeAllObjects];
    [self.privateUniversalRules removeAllObjects];
}

- (NSArray *)universalRules
{
    return self.privateUniversalRules;
}

- (NSArray *)idRulesWithKey:(NSString *)key
{
    return self.idRules[key];
}

- (NSArray *)tagRulesWithKey:(NSString *)key
{
    return self.tagRules[key];
}

- (NSArray *)classRulesWithKey:(NSString *)key
{
    return self.classRules[key];
}

- (NSArray *)pseudoRulesWithKey:(NSString *)key
{
    return self.pseudoRules[key];
}

- (void)mergeWithRuleSet:(SamuraiCssRuleSet *)ruleSet
{
    [self.idRules addEntriesFromDictionary:ruleSet.idRules];
    [self.tagRules addEntriesFromDictionary:ruleSet.tagRules];
    [self.classRules addEntriesFromDictionary:ruleSet.classRules];
    [self.pseudoRules addEntriesFromDictionary:ruleSet.pseudoRules];
    [self.privateUniversalRules addObjectsFromArray:ruleSet.privateUniversalRules];
    _ruleCount = self.idRules.count + self.tagRules.count + self.classRules.count + self.pseudoRules.count +
    self.privateUniversalRules.count;
}

- (void)addRulesFromSheet:(KatanaStylesheet *)sheet
{
    if ( !sheet )
        return;
    
    [self addChildRules:&sheet->imports];
    [self addChildRules:&sheet->rules];
}

- (void)addChildRules:(KatanaArray *)childRules
{
    for (int i=0; i<childRules->length; i++)
    {
        KatanaRule* rule = childRules->data[i];
        
        switch ( rule->type )
        {
            case KatanaRuleStyle:
                [self addStyleRule:(KatanaStyleRule *)rule];
                break;
            case KatanaRuleImport:
            {
                KatanaImportRule * import = (KatanaImportRule *)rule;
                
                if ( self.mediaQueryChecker &&
                    [self.mediaQueryChecker testMediaQueries:import->medias] )
                {
                    // TODO: @(QFish) handle import rule
                }
            }
                break;
            case KatanaRuleFontFace:
            {
                // TODO: @(QFish) handle font-face rule
            }
                break;
            case KatanaRuleKeyframes:
            {
                // TODO: @(QFish) handle keyframes rule
            }
                break;
            case KatanaRuleMedia:
            {
                KatanaMediaRule * mediaRule = (KatanaMediaRule *)rule;
                
                if ( self.mediaQueryChecker &&
                    [self.mediaQueryChecker testMediaQueries:mediaRule->medias] )
                {
                    [self addChildRules:mediaRule->rules];
                }
            }
                break;
            case KatanaRuleSupports:
            case KatanaRuleCharset:
            case KatanaRuleHost:
            case KatanaRuleUnkown:
                break;
        }
    }
}

- (void)addStyleRule:(KatanaStyleRule *)rule
{
    for (int i=0; i<rule->selectors->length; i++)
    {
        KatanaSelector * selector = rule->selectors->data[i];
        
        SamuraiCssRuleData * data = [[SamuraiCssRuleData alloc] initWithRule:rule
                                                                    selector:selector position:(self.ruleCount++)];
        
        [self collectFeaturesFromRuleData];
        
        if ( ![self findBestRuleSetAndAddWithSelector:selector ruleData:data] )
        {
            [_privateUniversalRules addObject:data];
        }
    }
}

- (void)collectFeaturesFromRuleData
{
    
}

- (BOOL)findBestRuleSetAndAddWithSelector:(KatanaSelector *)selector ruleData:(SamuraiCssRuleData *)ruleData
{
    if ( selector->match == KatanaSelectorMatchId )
    {
        [self addToRuleSet:_idRules key:selector->data->value ruleData:ruleData selector:selector];
        return YES;
    }
    
    if ( selector->match == KatanaSelectorMatchClass )
    {
        [self addToRuleSet:_classRules key:selector->data->value ruleData:ruleData selector:selector];
        return YES;
    }
    
    //    if ( [selector isCustomPseudoElement] )
    //    {
    //        [self addToRuleSet:_shadowPseudoElementRules key:selector->data->value ruleData:ruleData selector:selector];
    //        return YES;
    //    }
    //
    //    if ( [selector isCommonPseudoClassSelector] )
    //    {
    //        switch ( selector->pseudoType )
    //        {
    //            case KatanaSelectorPseudoLink:
    //            case KatanaSelectorPseudoVisited:
    //            case KatanaSelectorPseudoAnyLink:
    //                [_linkPseudoClassRules addObject:ruleData];
    //                return true;
    //            case KatanaSelectorPseudoFocus:
    //                [_focusPseudoClassRules addObject:ruleData];
    //                return true;
    //            default:
    //                return true;
    //        }
    //    }
    
    if ( selector->match == KatanaSelectorMatchTag )
    {
        // If this is part of a subselector chain, recurse ahead to find a narrower set (ID/class/:pseudo)
        
        if ( selector->relation == KatanaSelectorRelationSubSelector )
        {
            KatanaSelector * next = selector->tagHistory;
            if ( next->match == KatanaSelectorMatchClass
                || next->match == KatanaSelectorMatchId
                //                || [next isCommonPseudoClassSelector]
                )
            {
                if ( [self findBestRuleSetAndAddWithSelector:next ruleData:ruleData] )
                {
                    return YES;
                }
            }
        }
        
        //        if ( ![selector->tag.localName isEqualToString:@"*"] )
        {
            [self addToRuleSet:_tagRules key:selector->tag->local ruleData:ruleData selector:selector];
        }
    }
    
    return NO;
}

- (void)addToRuleSet:(NSMutableDictionary *)map
                 key:(const char*)key
            ruleData:(SamuraiCssRuleData *)ruleData
            selector:(KatanaSelector *)selector
{
    if (!key || !map || !ruleData)
        return;
    
    NSString * string = [NSString stringWithUTF8String:key];
    
    NSMutableArray * rules = [map objectForKey:string];
    
    if (!rules)
    {
        rules = [NSMutableArray array];
        [map setValue:rules forKey:string];
    }
    
    [rules addObject:ruleData];
}

@end

#pragma mark - SamuraiCssSelectorChecker

@interface SamuraiCssSelectorChecker : NSObject

+ (SamuraiCssSelectorMatch)checkSelector:(KatanaSelector *)selector
                                 element:(id<SamuraiCssProtocol>)elment
                                   attrs:(NSSet *)attrs;

@end

@implementation SamuraiCssSelectorChecker

+ (BOOL)selectorTagMatches:(id<SamuraiCssProtocol>)element selector:(KatanaSelector *)selector
{
    if ( !selector->tag )
        return true;
    
    NSString * localName = [NSString stringWithUTF8String:selector->tag->local];
    
    if ( [localName isEqualToString:[element cssTag]] )
        return true;
    if ( [localName isEqualToString:@"*"] )
        return true;
    
    return false;
}

+ (BOOL)checkOneSelector:(KatanaSelector *)selector element:(id<SamuraiCssProtocol>)element attrs:(NSSet *)attrs
{
    if ( nil == element )
        return false;
    
    if ( selector->match == KatanaSelectorMatchTag )
    {
        return [self selectorTagMatches:element selector:selector];
    }
    
    //    if (  [selector hasAttribute] )
    //    {
    if ( selector->data->value )
    {
        NSString * value = [NSString stringWithUTF8String:selector->data->value];
        
        if ( selector->match == KatanaSelectorMatchClass )
            return [element cssClasses] && [[element cssClasses] containsObject:value];
        
        if ( selector->match == KatanaSelectorMatchId )
            return [element cssId] && [[element cssId] isEqualToString:value];
        
        //        // TODO: attribute check
        //    }
        
        // TODO: pseudoClass check
        if ( selector->match == KatanaSelectorMatchPseudoClass || selector->match == KatanaSelectorMatchUnknown )
        {
            // any ":pseudo" is true.
            // TODO: should check if element has PseudoClass
            BOOL matched = true;
            
            //        switch ( selector->pseudoType )
            //        {
            //            case KatanaSelectorPseudoFirstChild:
            //                matched = [element isFirstChild];
            //                break;
            //            case KatanaSelectorPseudoLastChild:
            //                matched = [element isLastChild];
            //                break;
            //            case KatanaSelectorPseudoNthChild:
            //                matched = [element isNthChild:[selector->argument integerValue]];
            //                break;
            //            case KatanaSelectorPseudoUnknown:
            //            default:
            //                matched = true;
            //                break;
            //        }
            
            return matched;
        }
    }
    
    // TODO: PseudoElement check
    
    return false;
}

// Recursive check of selectors and combinators
// It can return 4 different values:
// * SelectorMatches          - the selector matches the element e
// * SelectorFailsLocally     - the selector fails for the element e
// * SelectorFailsAllSiblings - the selector fails for e and any sibling of e
// * SelectorFailsCompletely  - the selector fails for e and any sibling or ancestor of e
+ (SamuraiCssSelectorMatch)checkSelector:(KatanaSelector*)selector element:(id<SamuraiCssProtocol>)element attrs:(NSSet *)attrs
{
    if ( !element || ![element cssIsElement] )
        return SamuraiCssSelectorFailsCompletely;
    
    // first selector has to match
    BOOL checked = [self checkOneSelector:selector element:element attrs:attrs];
    if ( !checked )
        return SamuraiCssSelectorFailsLocally;
    
    // The rest of the selectors has to match
    NSUInteger relation = selector->relation;
    
    // Prepare next sel
    selector = selector->tagHistory;
    if ( !selector )
        return SamuraiCssSelectorMatches;
    
    // get the elment shadow pointer
    id<SamuraiCssProtocol> shadow = element;
    
    switch (relation) {
        case KatanaSelectorRelationDescendant: // selector1 selector2, 1 is 2's ancestor
            while (true)
            {
                SamuraiCssSelectorMatch match = [self checkSelector:selector element:shadow attrs:attrs];
                if ( match != SamuraiCssSelectorFailsLocally )
                    return match;
                shadow = [shadow cssParent];
            }
            break;
        case KatanaSelectorRelationChild: // selector1 > selector2, 1 is 2's parent
        {
            shadow = [shadow cssParent];
            return [self checkSelector:selector element:shadow attrs:attrs];
        }
        case KatanaSelectorRelationDirectAdjacent: // selector1 + selector2, 1 is 2's closest brother
        {
            shadow = [shadow cssSiblingAtIndex:-1];
            return [self checkSelector:selector element:shadow attrs:attrs];
        }
        case KatanaSelectorRelationIndirectAdjacent: // selector1 ~ selector2, 1 is 2's older brother
        {
            NSArray * siblings = [shadow cssPreviousSiblings];
            
            for ( id<SamuraiCssProtocol> brother in siblings )
            {
                if ( SamuraiCssSelectorMatches == [self checkSelector:selector element:brother attrs:attrs] )
                    return SamuraiCssSelectorMatches;
            }
            return SamuraiCssSelectorFailsLocally;
        }
        case KatanaSelectorRelationSubSelector:       // selector:pseudo
        case KatanaSelectorRelationShadowPseudo:      // selector::pseudo
        {
            // TODO: check more ~ check more ~
            return [self checkSelector:selector element:shadow attrs:attrs];
        }
    }
    
    return SamuraiCssSelectorFailsCompletely;
}

@end

#pragma mark - SamuraiCssRuleCollector

@interface SamuraiCssRuleCollector : NSObject

- (instancetype)initWithRuleSet:(SamuraiCssRuleSet *)ruleSet;
- (NSDictionary *)styleForElement:(id<SamuraiCssProtocol>)element;

@end


@interface SamuraiCssRuleCollector()

@property (nonatomic, strong, readonly) SamuraiCssRuleSet * ruleSet;
@property (nonatomic, strong, readonly) id<SamuraiCssProtocol> element;
@property (nonatomic, strong) NSMutableArray * matchedRules;
@property (nonatomic, strong) NSMutableDictionary * style;
@end

@implementation SamuraiCssRuleCollector

- (instancetype)initWithRuleSet:(SamuraiCssRuleSet *)ruleSet;
{
    self = [super init];
    if (self) {
        _ruleSet = ruleSet;
    }
    return self;
}

- (NSDictionary *)styleForElement:(id<SamuraiCssProtocol>)element
{
    if ( _element != element )
    {
        _element = element;
        
        [self collect];
        [self buildStyle];
    }
    
    return self.style;
}

#pragma mark -

- (void)collect
{
    [self clearMatchedRules];
    [self collectRulesForStyleable:self.element ruleSet:self.ruleSet];
    [self sortAndTransferMatchedRules];
}

- (void)buildStyle
{
    if ( _style ) {
        [_style removeAllObjects];
    } else {
        _style = [NSMutableDictionary dictionary];
    }
    
    for ( SamuraiCssRuleData * ruleData in self.matchedRules )
    {
        KatanaStyleRule * rule = ruleData.rule;
        
        for (size_t i=0; i<rule->declarations->length; i++)
        {
            KatanaDeclaration * decl = rule->declarations->data[i];
            
            if ( decl->property )
            {
                SamuraiCssValueWrapper * wrapper = [SamuraiCssValueWrapper new];
                // TODO: @(QFish) copy values, but no need for right now.
                // wrapper.values = decl->values;
                wrapper.rawValue = [NSString stringWithUTF8String:decl->raw];
                // NSLog( @"%@ %s :%@", [self.element cssClasses], decl->property, wrapper );
                [self.style setValue:wrapper forKey:[NSString stringWithUTF8String:decl->property]];
            }
        }
    }
}

- (void)sortAndTransferMatchedRules
{
    [_matchedRules sortUsingComparator:^NSComparisonResult(SamuraiCssRuleData * obj1, SamuraiCssRuleData * obj2) {
        NSUInteger specificity1 = obj1.specificity;
        NSUInteger specificity2 = obj2.specificity;
        // TODO: @(QFish) should consider position
        //        return (specificity1 == specificity2) ? obj1.position > obj2.position : specificity1 > specificity2;
        return specificity1 > specificity2;
    }];
}

#pragma mark -


- (void)clearMatchedRules
{
    [_matchedRules removeAllObjects];
}

- (void)collectRulesForStyleable:(id<SamuraiCssProtocol>)element ruleSet:(SamuraiCssRuleSet *)ruleSet
{
    // #id
    if ( [element cssId] )
    {
        [self collectMatchingRulesForList:[ruleSet idRulesWithKey:[element cssId]]];
    }
    // .class
    if ( [element cssClasses] )
    {
        for ( NSString * className in [element cssClasses] )
        {
            [self collectMatchingRulesForList:[ruleSet classRulesWithKey:className]];
        }
    }
    //   // :pseudo
    //    if ( [element supportPseudo] )
    //    {
    //        for ( NSString * pseudo in self.element.stylePseudos )
    //        {
    //            [self collectMatchingRulesForList:[ruleSet pseudoRulesWithKey:pseudo]];
    //        }
    //    }
    //
    // element
    if ( [element cssTag] )
    {
        [self collectMatchingRulesForList:[ruleSet tagRulesWithKey:[element cssTag]]];
    }
    // * or ...
    [self collectMatchingRulesForList:[ruleSet universalRules]];
}

- (void)collectMatchingRulesForList:(NSArray *)rules
{
    if ( !rules )
        return;
    
    for ( SamuraiCssRuleData * ruleData in rules )
    {
        if ( [self ruleMatchesStylable:self.element ruleData:ruleData] )
        {
            [self.matchedRules addObject:ruleData];
        }
    }
}

- (BOOL)ruleMatchesStylable:(id<SamuraiCssProtocol>)element ruleData:(SamuraiCssRuleData *)ruleData
{
    SamuraiCssSelectorMatch matches = \
    [SamuraiCssSelectorChecker checkSelector:ruleData.selector
                                     element:self.element
                                       attrs:nil];
    
    return matches == SamuraiCssSelectorMatches;
}

- (NSMutableArray *)matchedRules
{
    if ( !_matchedRules ) {
        _matchedRules = [NSMutableArray array];
    }
    return _matchedRules;
}

@end

#pragma mark - 
#pragma mark - SamuraiCssStyleSheet

@interface SamuraiCssStyleSheet()
@prop_unsafe( KatanaOutput *, output );
@prop_strong( SamuraiCssRuleCollector*, styleCollector );
@end

@implementation SamuraiCssStyleSheet

@def_prop_strong( SamuraiCssRuleSet *, ruleSet );
@def_prop_strong( SamuraiCssRuleCollector*, styleCollector );
@def_prop_unsafe( KatanaOutput *, output)

- (id)init
{
	self = [super init];
	if ( self )
	{
        _ruleSet = [SamuraiCssRuleSet new];
        _ruleSet.mediaQueryChecker = [SamuraiHtmlMediaQuery sharedInstance];
	}
	return self;
}

- (void)dealloc
{
    if ( self.output != NULL ) {
        katana_destroy_output(self.output);
        self.output = NULL;
    }
}

#pragma mark -

+ (NSArray *)supportedExtensions
{
	return [NSArray arrayWithObjects:@"css", nil];
}

+ (NSArray *)supportedTypes
{
	return [NSArray arrayWithObjects:@"text/css", nil];
}

+ (NSString *)baseDirectory
{
	return @"/www/css";
}

#pragma mark -

- (NSDictionary *)queryForObject:(NSObject<SamuraiCssProtocol> *)object
{
    return [self.styleCollector styleForElement:object];
}

- (NSDictionary *)queryForString:(NSString *)string
{
	ASSERT( 0 );
	
	// TODO:
	
	return nil;
}

#pragma mark -

- (BOOL)parse
{
	if ( nil == self.resContent || 0 == [self.resContent length] )
		return NO;

	self.output = [[SamuraiCssParser sharedInstance] parseStylesheet:self.resContent];
    
	if ( NULL == self.output )
		return NO;
    
    KatanaStylesheet * stylesheet = self.output->stylesheet;
    
    if ( stylesheet->rules.length )
    {
        [self.ruleSet addRulesFromSheet:stylesheet];
    }

	return YES;
}

- (void)merge:(SamuraiCssStyleSheet *)styleSheet
{
	if ( nil == styleSheet )
		return;
	
	if ( NO == [styleSheet isKindOfClass:[SamuraiCssStyleSheet class]] )
		return;
    
    [self.ruleSet mergeWithRuleSet:styleSheet.ruleSet];
}

- (void)clear
{
    [self.ruleSet clear];
}

- (SamuraiCssRuleCollector *)styleCollector
{
    if ( _styleCollector == nil ) {
         _styleCollector = [[SamuraiCssRuleCollector alloc] initWithRuleSet:self.ruleSet];
    }
    return _styleCollector;
}

@end

// ----------------------------------
// Unit test
// ----------------------------------

#pragma mark -

#if __SAMURAI_TESTING__

TEST_CASE( UI, CssStyleSheet_Default )
{
	//	TODO( @"test case" )
}
TEST_CASE_END

#endif	// #if __SAMURAI_TESTING__

#endif	// #if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

#import "_pragma_pop.h"
