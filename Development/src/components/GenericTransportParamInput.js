import React, { useRef } from 'react';
import { TextField } from '@material-ui/core';
import Autocomplete from '@material-ui/lab/Autocomplete';
import CheckIcon from '@material-ui/icons/Check';
import ClearIcon from '@material-ui/icons/Clear';
import { TextInput } from 'react-admin';
import { useField } from 'react-final-form';

const optionLabel = option => {
    if (option === true) return 'true';
    if (option === false) return 'false';
    if (option == null) return '';
    return String(option);
};

// '' clears the field, 'auto' is that string, true and false are booleans.
// undefined means the text is not one of those and should be discarded.
export const booleanOrAutoValue = text => {
    const trimmed = text.trim();
    if (trimmed === '') return '';
    if (trimmed === 'auto') return 'auto';
    if (trimmed === 'true') return true;
    if (trimmed === 'false') return false;
    return undefined;
};

const GenericBooleanInput = ({ className, label, source }) => {
    const {
        input: { value, onChange, onBlur, onFocus },
    } = useField(source, { initialValue: undefined });
    const atFocus = useRef(value);
    const latest = useRef(value);
    latest.current = value;

    const commit = next => {
        latest.current = next;
        onChange(next);
    };

    return (
        <Autocomplete
            className={className}
            freeSolo
            options={[true, false]}
            // the menu stays tick/cross even when the field shows "auto"
            filterOptions={options => options}
            value={value === '' || value == null ? null : value}
            getOptionLabel={optionLabel}
            getOptionSelected={(option, selected) => option === selected}
            onFocus={event => {
                atFocus.current = value;
                onFocus(event);
            }}
            onChange={(event, newValue, reason) => {
                commit(reason === 'clear' || newValue == null ? '' : newValue);
            }}
            onInputChange={(event, newInput, reason) => {
                if (reason === 'input') commit(newInput);
                if (reason === 'clear') commit('');
            }}
            onBlur={event => {
                if (typeof latest.current === 'string') {
                    const parsed = booleanOrAutoValue(latest.current);
                    commit(parsed === undefined ? atFocus.current : parsed);
                }
                onBlur(event);
            }}
            renderOption={option =>
                option === true ? <CheckIcon /> : <ClearIcon />
            }
            renderInput={params => (
                <TextField
                    {...params}
                    label={label}
                    margin="dense"
                    variant="filled"
                />
            )}
        />
    );
};

// Tick/cross when any leg is already a boolean. Otherwise a text field.
const GenericTransportParamInput = ({ types, ...props }) =>
    types.includes('boolean') ? (
        <GenericBooleanInput {...props} />
    ) : (
        <TextInput {...props} />
    );

export default GenericTransportParamInput;
