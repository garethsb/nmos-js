import React from 'react';
import {
    Edit,
    EditContextProvider,
    SaveButton,
    SimpleForm,
    TextInput,
    Toolbar,
    useEditController,
} from 'react-admin';
import ObjectInput from '../../components/ObjectInput';
import ResourceTitle from '../../components/ResourceTitle';

export const NodesEdit = props => {
    const controllerProps = useEditController(props);
    return (
        <EditContextProvider value={controllerProps}>
            <NodesEditView {...props} />
        </EditContextProvider>
    );
};

const NodesEditToolbar = props => (
    <Toolbar {...props}>
        <SaveButton />
    </Toolbar>
);

const NodesEditView = props => (
    <Edit {...props} undoable={false} title={<ResourceTitle />}>
        <SimpleForm toolbar={<NodesEditToolbar />} redirect="show">
            <TextInput source="label" />
            <TextInput source="description" />
            <ObjectInput source="tags" />
        </SimpleForm>
    </Edit>
);

export default NodesEdit;
