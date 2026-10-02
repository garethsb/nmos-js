import { booleanOrAutoValue } from './GenericTransportParamInput';

describe('booleanOrAutoValue', () => {
    it('accepts a boolean, auto, or an empty field', () => {
        expect(booleanOrAutoValue('true')).toBe(true);
        expect(booleanOrAutoValue(' false ')).toBe(false);
        expect(booleanOrAutoValue('auto')).toBe('auto');
        expect(booleanOrAutoValue('  ')).toBe('');
    });

    it('rejects any other text', () => {
        expect(booleanOrAutoValue('meow')).toBeUndefined();
        expect(booleanOrAutoValue('5004')).toBeUndefined();
    });
});
