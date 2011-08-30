#import "BZGeometry.h"

//returns a + b.
NSSize BZAddSizes(NSSize a, NSSize b) {
	return (NSSize){
		a.width  + b.width,
		a.height + b.height
	};
}

//returns from - delta.
NSSize BZSubtractSizes(NSSize from, NSSize delta) {
	return (NSSize){
		from.width  - delta.width,
		from.height - delta.height
	};
}

//returns a * b.
NSSize BZMultiplySizes(NSSize a, NSSize b) {
	return (NSSize){
		a.width  * b.width,
		a.height * b.height
	};
}